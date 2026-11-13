/**
 * Copyright 2026 Salesforce, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

'use strict';

var Site = require('dw/system/Site');
var Logger = require('dw/system/Logger');
var CacheMgr = require('dw/system/CacheMgr');
var svc = require('*/cartridge/scripts/services/schedulerCoreService');

var log = Logger.getLogger('sfnext-appointment', 'sfnext-appointment');

var SLOT_HOLDS_CACHE = 'sfnextSlotHoldCounters';
var SLOT_AVAIL_CACHE = 'sfnextSlotAvailability';

function escapeSoql(val) {
    return String(val).replace(/\\/g, '\\\\').replace(/'/g, "\\'");
}

var EXTERNAL_ID_PATTERN = /^[A-Za-z0-9_\-]{1,64}$/;
function isValidExternalId(val) {
    return typeof val === 'string' && EXTERNAL_ID_PATTERN.test(val);
}

/**
 * Non-secret Core scheduling config, read from site custom preferences (see impex
 * SitePreferences.xml). The Core origin + OAuth client id/secret live on the Service
 * credential, not here.
 */
function pref(name, fallback) {
    try {
        var v = Site.current.getCustomPreferenceValue(name);
        return v === null || v === undefined || v === '' ? fallback : v;
    } catch (e) {
        return fallback;
    }
}

function getConfig() {
    return {
        apiVersion: pref('sfnextSchedulerApiVersion', 'v64.0'),
        parentRecordId: pref('sfnextSchedulerParentRecordId', ''),
        schedulingPolicyId: pref('sfnextSchedulerPolicyId', ''),
        serviceResourceId: pref('sfnextSchedulerResourceId', '')
    };
}

function mapStatus(status) {
    if (status === 400 || status === 404) return 'INVALID_REQUEST';
    if (status === 401 || status === 403) return 'SCHEDULER_AUTHORIZATION';
    if (status === 429) return 'SCHEDULER_RATE_LIMITED';
    return 'SCHEDULER_UNAVAILABLE';
}

/** Acquire a client-credentials access token from the Core org via the Service Framework. */
function getToken() {
    var cache = CacheMgr.getCache('sfnextSchedulerToken');
    var cacheKey = Site.current.ID + ':token';
    var cached = cache.get(cacheKey);
    if (cached) {
        return { ok: true, token: cached };
    }
    var res = svc.tokenService().call();
    if (!res.ok) {
        log.error('scheduler token failed status={0} msg={1}', res.error, res.errorMessage);
        return { ok: false, code: (res.error === 401 || res.error === 403) ? 'SCHEDULER_AUTHORIZATION' : 'SCHEDULER_UNAVAILABLE' };
    }
    var data = res.object;
    if (!data || !data.access_token) {
        return { ok: false, code: 'SCHEDULER_AUTHORIZATION' };
    }
    cache.put(cacheKey, data.access_token);
    return { ok: true, token: data.access_token };
}

/**
 * Atomically increment a Platform Cache slot-hold counter and grant the hold when
 * the resulting count is within `max`. Returns true if the hold was granted, false
 * if the slot is already at capacity.
 *
 * Note: CacheMgr.put is not a hardware CAS — two concurrent requests may both read
 * the same value before either writes. The final backstop remains the Core
 * AssignedResource creation (which will reject the second booking at the record level).
 * This counter provides a fast pre-flight that eliminates the TOCTOU race in the
 * common case without an additional SOQL query.
 *
 * @param {string} key  - e.g. siteId:resourceId:startTime
 * @param {number} max  - maximum concurrent holds (typically 1 per advisor slot)
 * @returns {boolean}
 */
function checkAndIncrementHold(key, max) {
    var cache = CacheMgr.getCache(SLOT_HOLDS_CACHE);
    var ttl = Number(pref('sfnextAppointmentCacheTtlSeconds', 10));
    var current = cache.get(key);
    var count = (current !== null && current !== undefined) ? Number(current) : 0;
    if (count >= max) return false;
    cache.put(key, count + 1, ttl);
    return true;
}

/**
 * Decrement the Platform Cache slot-hold counter when a booking attempt fails or is
 * rolled back. Never decrements below 0.
 *
 * @param {string} key - must match the key used in checkAndIncrementHold
 */
function decrementHold(key) {
    var cache = CacheMgr.getCache(SLOT_HOLDS_CACHE);
    var ttl = Number(pref('sfnextAppointmentCacheTtlSeconds', 10));
    var current = cache.get(key);
    var count = (current !== null && current !== undefined) ? Number(current) : 0;
    if (count > 0) {
        cache.put(key, count - 1, ttl);
    }
}

/**
 * Get consolidated availability for the configured territory + work-type group.
 * Results are cached in sfnextSlotAvailability to reduce Core API calls under load.
 * The Connect REST response is wrapped in a `result` envelope — unwrap it.
 * @param {Object} window - { startTime, endTime, storeId? } ISO 8601
 */
function getAvailability(window) {
    var cfg = getConfig();

    // Check availability cache before hitting Core.
    var availCacheKey = Site.current.ID + ':avail:' + (window.territoryId || '') + ':' + (window.workTypeGroupId || '') + ':' + window.startTime + ':' + window.endTime;
    var cachedAvail = CacheMgr.getCache(SLOT_AVAIL_CACHE).get(availCacheKey);
    if (cachedAvail) return cachedAvail;

    var tokenRes = getToken();
    if (!tokenRes.ok) {
        return { ok: false, code: tokenRes.code };
    }

    // Territory: resolve SF record Id from ExternalId or use SF Id directly (zero-provisioning).
    var territoryId = null;
    var territoryTimezone = null;

    if (window.territoryId) {
        var isSfId = /^[a-zA-Z0-9]{15}$/.test(window.territoryId) || /^[a-zA-Z0-9]{18}$/.test(window.territoryId);
        var terrFilter = isSfId
            ? 'Id = \'' + escapeSoql(window.territoryId) + '\''
            : 'ExternalId__c = \'' + escapeSoql(window.territoryId) + '\'';
        var terrSoql = 'SELECT Id, OperatingHours.TimeZone FROM ServiceTerritory WHERE ' + terrFilter + ' LIMIT 1';
        var lookupRes = svc.apiService().call({
            method: 'GET',
            path: '/services/data/' + cfg.apiVersion + '/query?q=' + encodeURIComponent(terrSoql),
            token: tokenRes.token
        });
        if (lookupRes.ok) {
            try {
                var lookupJson = JSON.parse(lookupRes.object.text);
                if (lookupJson.records && lookupJson.records[0]) {
                    territoryId = lookupJson.records[0].Id;
                    if (lookupJson.records[0].OperatingHours && lookupJson.records[0].OperatingHours.TimeZone) {
                        territoryTimezone = lookupJson.records[0].OperatingHours.TimeZone;
                    }
                }
            } catch (e) { /* non-fatal */ }
        }
        // If lookup returned nothing the input is already a valid SF Id — use directly.
        if (!territoryId && isSfId) {
            territoryId = window.territoryId;
        }
    }

    if (!territoryId) {
        return { ok: false, code: 'SCHEDULER_NOT_CONFIGURED' };
    }

    // workTypeGroupId must come from the request (resolved per territory by getWorkTypes).
    if (!window.workTypeGroupId) {
        return { ok: false, code: 'SCHEDULER_NOT_CONFIGURED' };
    }

    var body = {
        startTime: window.startTime,
        endTime: window.endTime,
        territoryIds: [territoryId],
        workTypeGroupId: window.workTypeGroupId
    };
    if (cfg.schedulingPolicyId) {
        body.schedulingPolicyId = cfg.schedulingPolicyId;
    }
    if (cfg.serviceResourceId) {
        body.requiredResourceIds = [cfg.serviceResourceId];
    }

    var avRes = svc.apiService().call({
        method: 'POST',
        path: '/services/data/' + cfg.apiVersion + '/connect/scheduling/available-territory-slots',
        token: tokenRes.token,
        body: body
    });
    if (!avRes.ok && avRes.error === 401) {
        CacheMgr.getCache('sfnextSchedulerToken').invalidate(Site.current.ID + ':token');
        var retryTokenRes = getToken();
        if (!retryTokenRes.ok) {
            return { ok: false, code: retryTokenRes.code };
        }
        avRes = svc.apiService().call({
            method: 'POST',
            path: '/services/data/' + cfg.apiVersion + '/connect/scheduling/available-territory-slots',
            token: retryTokenRes.token,
            body: body
        });
    }
    if (!avRes.ok) {
        log.error('scheduler availability failed status={0} msg={1}', avRes.error, avRes.errorMessage);
        return { ok: false, code: mapStatus(avRes.error) };
    }

    var json;
    try {
        json = JSON.parse(avRes.object.text);
    } catch (e) {
        return { ok: false, code: 'SCHEDULER_UNAVAILABLE' };
    }
    var envelope = json && json.result ? json.result : json;
    var territorySlots = (envelope && envelope.territorySlots) || [];
    var slots = [];
    for (var i = 0; i < territorySlots.length; i++) {
        var ts = territorySlots[i].slots || [];
        for (var j = 0; j < ts.length; j++) {
            slots.push({ startTime: ts[j].startTime, endTime: ts[j].endTime, resources: ts[j].resources });
        }
    }

    var advanceNoticeMinutes = Number(pref('sfnextAppointmentAdvanceNoticeMinutes', 120)) || 120;
    var availResult = { ok: true, slots: slots, timezone: territoryTimezone, advanceNoticeMinutes: advanceNoticeMinutes };
    var availTtl = Number(pref('sfnextSlotCacheTtlSeconds', 30));
    CacheMgr.getCache(SLOT_AVAIL_CACHE).put(availCacheKey, availResult, availTtl);
    return availResult;
}

/**
 * Create a ServiceAppointment (no Contact — shopper identity on ExternalId__c), then assign the
 * configured required resource so the slot is consumed. The Core record-triggered Flow emails the
 * confirmation.
 * @param {Object} input - { schedStartTime, schedEndTime, email, b2cCustomerId, subject?, storeId?, serviceId? }
 */
function bookAppointment(input) {
    var cfg = getConfig();
    if (!cfg.parentRecordId) {
        return { ok: false, code: 'SCHEDULER_NOT_CONFIGURED' };
    }
    var tokenRes = getToken();
    if (!tokenRes.ok) {
        return { ok: false, code: tokenRes.code };
    }

    // Territory: resolve SF record Id from ExternalId__c or use SF Id directly.
    var resolvedTerritoryId = null;
    if (input.territoryId) {
        var isTerritoryId = /^[a-zA-Z0-9]{15}$/.test(input.territoryId) || /^[a-zA-Z0-9]{18}$/.test(input.territoryId);
        var terrFilter = isTerritoryId
            ? 'Id = \'' + escapeSoql(input.territoryId) + '\''
            : 'ExternalId__c = \'' + escapeSoql(input.territoryId) + '\'';
        var territorySoql = 'SELECT Id FROM ServiceTerritory WHERE ' + terrFilter + ' LIMIT 1';
        var territoryLookup = svc.apiService().call({
            method: 'GET',
            path: '/services/data/' + cfg.apiVersion + '/query?q=' + encodeURIComponent(territorySoql),
            token: tokenRes.token
        });
        if (territoryLookup.ok) {
            try {
                var tJson = JSON.parse(territoryLookup.object.text);
                if (tJson.records && tJson.records[0]) resolvedTerritoryId = tJson.records[0].Id;
            } catch (e) { /* non-fatal */ }
        }
        if (!resolvedTerritoryId && isTerritoryId) resolvedTerritoryId = input.territoryId;
    }

    // WorkType: passed as SF record Id directly from getWorkTypes response.
    var resolvedWorkTypeId = input.workTypeId || null;

    if (!resolvedTerritoryId || !resolvedWorkTypeId) {
        return { ok: false, code: 'SCHEDULER_NOT_CONFIGURED' };
    }

    // Acquire a Platform Cache slot hold before creating the SA to prevent the TOCTOU
    // race where two concurrent requests both pass the SOQL overlap check and attempt
    // to book the same advisor slot simultaneously.
    var holdKey = Site.current.ID + ':' + resolvedTerritoryId + ':' + (cfg.serviceResourceId || 'any') + ':' + input.schedStartTime;
    if (!checkAndIncrementHold(holdKey, 1)) {
        log.warn('scheduler slot hold denied — slot at capacity key={0}', holdKey);
        return { ok: false, code: 'SCHEDULER_SLOT_TAKEN' };
    }

    var saBody = {
        ParentRecordId: cfg.parentRecordId,
        ServiceTerritoryId: resolvedTerritoryId,
        WorkTypeId: resolvedWorkTypeId,
        Status: 'Scheduled',
        SchedStartTime: input.schedStartTime,
        SchedEndTime: input.schedEndTime,
        Email: input.email,
        ExternalId__c: input.b2cCustomerId
    };
    if (input.subject) {
        saBody.Subject = input.subject;
    }

    var saRes = svc.apiService().call({
        method: 'POST',
        path: '/services/data/' + cfg.apiVersion + '/sobjects/ServiceAppointment',
        token: tokenRes.token,
        body: saBody
    });
    if (!saRes.ok && saRes.error === 401) {
        CacheMgr.getCache('sfnextSchedulerToken').invalidate(Site.current.ID + ':token');
        var saRetryTokenRes = getToken();
        if (!saRetryTokenRes.ok) {
            return { ok: false, code: saRetryTokenRes.code };
        }
        tokenRes = saRetryTokenRes;
        saRes = svc.apiService().call({
            method: 'POST',
            path: '/services/data/' + cfg.apiVersion + '/sobjects/ServiceAppointment',
            token: tokenRes.token,
            body: saBody
        });
    }
    if (!saRes.ok) {
        decrementHold(holdKey);
        log.error('scheduler booking failed status={0} msg={1}', saRes.error, saRes.errorMessage);
        return { ok: false, code: mapStatus(saRes.error) };
    }

    var created;
    try {
        created = JSON.parse(saRes.object.text);
    } catch (e) {
        return { ok: false, code: 'SCHEDULER_UNAVAILABLE' };
    }
    if (!created || !created.id) {
        return { ok: false, code: 'SCHEDULER_UNAVAILABLE' };
    }

    // Assign the required resource so the slot is consumed (anti-double-booking).
    // If assignment fails, roll back by deleting the ServiceAppointment.
    if (cfg.serviceResourceId) {
        var arRes = svc.apiService().call({
            method: 'POST',
            path: '/services/data/' + cfg.apiVersion + '/sobjects/AssignedResource',
            token: tokenRes.token,
            body: {
                ServiceAppointmentId: created.id,
                ServiceResourceId: cfg.serviceResourceId,
                IsRequiredResource: true
            }
        });
        if (!arRes.ok) {
            decrementHold(holdKey);
            log.error('scheduler assigned-resource failed sa={0} status={1} — rolling back SA', created.id, arRes.error);
            svc.apiService().call({
                method: 'DELETE',
                path: '/services/data/' + cfg.apiVersion + '/sobjects/ServiceAppointment/' + created.id,
                token: tokenRes.token
            });
            return { ok: false, code: 'SCHEDULER_UNAVAILABLE' };
        }
        var assignedResourceId = null;
        try {
            var ar = JSON.parse(arRes.object.text);
            if (ar && ar.id) {
                assignedResourceId = ar.id;
            }
        } catch (e) {
            // non-fatal parse error; AR was created (arRes.ok === true)
        }
        return { ok: true, serviceAppointmentId: created.id, assignedResourceId: assignedResourceId };
    }

    return { ok: true, serviceAppointmentId: created.id };
}

/**
 * List active ServiceTerritory records, optionally filtered by SN_SiteId__c.
 * @param {Object} input - { siteId? }
 */
function getServiceTerritories(input) {
    var tokenRes = getToken();
    if (!tokenRes.ok) {
        return { success: false, error: { code: tokenRes.code } };
    }
    var cfg = getConfig();

    var soql = 'SELECT Id, Name, ExternalId__c, SN_SiteId__c, SN_Address1__c, SN_City__c, SN_PostalCode__c, SN_StateCode__c, SN_CountryCode__c, SN_Phone__c, SN_Latitude__c, SN_Longitude__c, OperatingHours.TimeZone FROM ServiceTerritory WHERE IsActive = true';
    if (input && input.siteId) {
        soql += ' AND SN_SiteId__c = \'' + escapeSoql(input.siteId) + '\'';
    }
    soql += ' ORDER BY Name ASC';

    var res = svc.apiService().call({
        method: 'GET',
        path: '/services/data/' + cfg.apiVersion + '/query?q=' + encodeURIComponent(soql),
        token: tokenRes.token
    });
    if (!res.ok) {
        log.error('getServiceTerritories failed status={0} msg={1}', res.error, res.errorMessage);
        return { success: false, error: { code: 'SCHEDULER_UNAVAILABLE' } };
    }

    var json;
    try {
        json = JSON.parse(res.object.text);
    } catch (e) {
        return { success: false, error: { code: 'SCHEDULER_UNAVAILABLE' } };
    }

    var records = (json && json.records) || [];
    var territories = [];
    for (var i = 0; i < records.length; i++) {
        var r = records[i];
        var t = {
            id: r.ExternalId__c || r.Id,
            sfId: r.Id,
            name: r.Name,
            timezone: (r.OperatingHours && r.OperatingHours.TimeZone) || 'UTC'
        };
        if (r.ExternalId__c) t.externalId = r.ExternalId__c;
        if (r.SN_SiteId__c) t.siteId = r.SN_SiteId__c;
        if (r.SN_Address1__c) t.address1 = r.SN_Address1__c;
        if (r.SN_City__c) t.city = r.SN_City__c;
        if (r.SN_PostalCode__c) t.postalCode = r.SN_PostalCode__c;
        if (r.SN_StateCode__c) t.stateCode = r.SN_StateCode__c;
        if (r.SN_CountryCode__c) t.countryCode = r.SN_CountryCode__c;
        if (r.SN_Phone__c) t.phone = r.SN_Phone__c;
        if (r.SN_Latitude__c != null) t.latitude = r.SN_Latitude__c;
        if (r.SN_Longitude__c != null) t.longitude = r.SN_Longitude__c;
        territories.push(t);
    }
    return { success: true, territories: territories };
}

/**
 * List WorkTypes for a territory (via WorkTypeGroup membership), or fall back to the
 * site-pref workTypeGroupId.
 * @param {Object} input - { territoryId? } — SF record Id OR ExternalId__c value
 */
function getWorkTypes(input) {
    var tokenRes = getToken();
    if (!tokenRes.ok) {
        return { success: false, error: { code: tokenRes.code } };
    }
    var cfg = getConfig();

    var groupId = cfg.workTypeGroupId;

    if (input && input.territoryId) {
        var id = input.territoryId;
        var isSfId = /^[a-zA-Z0-9]{15}$/.test(id) || /^[a-zA-Z0-9]{18}$/.test(id);
        var stwtFilter = isSfId
            ? 'ServiceTerritoryId = \'' + escapeSoql(id) + '\''
            : 'ServiceTerritory.ExternalId__c = \'' + escapeSoql(id) + '\'';

        var stwtSoql = 'SELECT WorkTypeId FROM ServiceTerritoryWorkType WHERE ' + stwtFilter + ' LIMIT 1';
        var stwtRes = svc.apiService().call({
            method: 'GET',
            path: '/services/data/' + cfg.apiVersion + '/query?q=' + encodeURIComponent(stwtSoql),
            token: tokenRes.token
        });
        var anchorWtId = null;
        if (stwtRes.ok) {
            try {
                var stwtJson = JSON.parse(stwtRes.object.text);
                if (stwtJson.records && stwtJson.records[0] && stwtJson.records[0].WorkTypeId) {
                    anchorWtId = stwtJson.records[0].WorkTypeId;
                }
            } catch (e) { /* fall through to cfg.workTypeGroupId */ }
        }

        if (anchorWtId) {
            var wtgmSoql = 'SELECT WorkTypeGroupId FROM WorkTypeGroupMember WHERE WorkTypeId = \'' + escapeSoql(anchorWtId) + '\' LIMIT 1';
            var wtgmRes = svc.apiService().call({
                method: 'GET',
                path: '/services/data/' + cfg.apiVersion + '/query?q=' + encodeURIComponent(wtgmSoql),
                token: tokenRes.token
            });
            if (wtgmRes.ok) {
                try {
                    var wtgmJson = JSON.parse(wtgmRes.object.text);
                    if (wtgmJson.records && wtgmJson.records[0] && wtgmJson.records[0].WorkTypeGroupId) {
                        groupId = wtgmJson.records[0].WorkTypeGroupId;
                    }
                } catch (e) { /* fall through */ }
            }
        }
    }

    if (!groupId) {
        return { success: false, error: { code: 'SCHEDULER_NOT_CONFIGURED' } };
    }

    var membersSoql = 'SELECT WorkType.Id, WorkType.Name, WorkType.EstimatedDuration FROM WorkTypeGroupMember WHERE WorkTypeGroupId = \'' + escapeSoql(groupId) + '\' ORDER BY WorkType.Name ASC';
    var membersRes = svc.apiService().call({
        method: 'GET',
        path: '/services/data/' + cfg.apiVersion + '/query?q=' + encodeURIComponent(membersSoql),
        token: tokenRes.token
    });
    if (!membersRes.ok) {
        log.error('getWorkTypes members failed status={0} msg={1}', membersRes.error, membersRes.errorMessage);
        return { success: false, error: { code: 'SCHEDULER_UNAVAILABLE' } };
    }

    var membersJson;
    try {
        membersJson = JSON.parse(membersRes.object.text);
    } catch (e) {
        return { success: false, error: { code: 'SCHEDULER_UNAVAILABLE' } };
    }

    var memberRecords = (membersJson && membersJson.records) || [];
    var workTypes = [];
    for (var k = 0; k < memberRecords.length; k++) {
        var m = memberRecords[k];
        if (!m.WorkType) continue;
        workTypes.push({
            id: m.WorkType.Id,
            name: m.WorkType.Name,
            durationMinutes: m.WorkType.EstimatedDuration,
            workTypeGroupId: groupId
        });
    }
    return { success: true, workTypes: workTypes };
}

module.exports = {
    getAvailability: getAvailability,
    bookAppointment: bookAppointment,
    getServiceTerritories: getServiceTerritories,
    getWorkTypes: getWorkTypes,
    checkAndIncrementHold: checkAndIncrementHold,
    decrementHold: decrementHold
};
