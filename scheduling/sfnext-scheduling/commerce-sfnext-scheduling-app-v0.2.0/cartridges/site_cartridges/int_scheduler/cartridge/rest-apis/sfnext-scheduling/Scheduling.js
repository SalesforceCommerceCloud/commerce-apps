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

var RESTResponseMgr = require('dw/system/RESTResponseMgr');
var Logger = require('dw/system/Logger');

var log = Logger.getLogger('sfnext-appointment', 'sfnext-appointment');

var ISO_DATETIME = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?(?:Z|[+-]\d{2}:\d{2})$/;

/** Map an internal scheduler error code to an HTTP status + SCAPI error render. */
function renderError(code) {
    var statuses = {
        INVALID_REQUEST: 400,
        SCHEDULER_NOT_CONFIGURED: 503,
        SCHEDULER_AUTHORIZATION: 502,
        SCHEDULER_RATE_LIMITED: 429,
        SCHEDULER_UNAVAILABLE: 503,
        SCHEDULER_SLOT_TAKEN: 409
    };
    var status = statuses[code] || 503;
    RESTResponseMgr.createError(status, code, 'Scheduler error', code).render();
}

function paramString(name) {
    var p = request.httpParameterMap.get(name);
    return p && p.submitted ? p.stringValue : null;
}

/**
 * GET /custom/sfnext-appointment/v1/appointment-availability
 *
 * Availability is public (same for every shopper); the SCAPI gateway enforces the
 * c_sfnext_appointment scope before this handler runs.
 */
exports.getAppointmentAvailability = function () {
    var schedulerCore = require('*/cartridge/scripts/helpers/schedulerCore');

    var startTime = paramString('c_startTime');
    var endTime = paramString('c_endTime');
    if (!startTime || !endTime || !ISO_DATETIME.test(startTime) || !ISO_DATETIME.test(endTime)) {
        RESTResponseMgr.createError(400, 'INVALID_REQUEST', 'Bad Request', 'c_startTime and c_endTime must be ISO 8601').render();
        return;
    }

    var territoryId = paramString('c_territoryId');
    var workTypeGroupId = paramString('c_workTypeGroupId');
    var result = schedulerCore.getAvailability({ startTime: startTime, endTime: endTime, territoryId: territoryId || null, workTypeGroupId: workTypeGroupId || null });
    if (!result.ok) {
        renderError(result.code);
        return;
    }
    var successBody = { success: true, slots: result.slots };
    if (result.timezone) successBody.timezone = result.timezone;
    if (typeof result.advanceNoticeMinutes === 'number') successBody.advanceNoticeMinutes = result.advanceNoticeMinutes;
    RESTResponseMgr.createSuccess(successBody).render();
};
exports.getAppointmentAvailability.public = true;

/**
 * POST /custom/sfnext-appointment/v1/appointments
 *
 * `b2cCustomerId` is derived server-side from the authenticated SCAPI shopper session
 * (`session.customer.ID`). This prevents a caller with the `c_sfnext_appointment` scope
 * from booking under an arbitrary shopper identity — the value is never trusted from the
 * request body.
 */
exports.createAppointment = function () {
    var schedulerCore = require('*/cartridge/scripts/helpers/schedulerCore');

    // Derive b2cCustomerId from the authenticated shopper session — NEVER from the request body.
    // The SCAPI gateway validates the ShopperToken before this handler runs, so session.customer
    // is always the token-authenticated shopper.
    var customer = session.customer;
    if (!customer || !customer.isAuthenticated()) {
        RESTResponseMgr.createError(401, 'SCHEDULER_AUTHORIZATION', 'Unauthorized', 'A registered shopper session is required').render();
        return;
    }
    var b2cCustomerId = customer.ID;

    // Read name from the authenticated shopper's B2C profile (registered shoppers only).
    // No extra API call needed — customer.profile is available from the DW session.
    var firstName = (customer.profile && customer.profile.firstName) ? String(customer.profile.firstName) : '';
    var lastName  = (customer.profile && customer.profile.lastName)  ? String(customer.profile.lastName)  : '';

    // Locale from the current site request (e.g. "en_US", "en_GB").
    var locale = (request.locale && request.locale.ID) ? String(request.locale.ID) : '';

    var body;
    try {
        body = JSON.parse(request.httpParameterMap.requestBodyAsString);
    } catch (e) {
        RESTResponseMgr.createError(400, 'INVALID_REQUEST', 'Bad Request', 'Request body is not valid JSON').render();
        return;
    }
    if (!body || typeof body !== 'object') {
        RESTResponseMgr.createError(400, 'INVALID_REQUEST', 'Bad Request', 'Missing request body').render();
        return;
    }

    var schedStartTime = body.schedStartTime;
    var schedEndTime = body.schedEndTime;

    // Email: prefer the authenticated shopper's profile email; fall back to request body.
    var email = (customer.profile && customer.profile.email) ? String(customer.profile.email) : body.email;

    if (!ISO_DATETIME.test(String(schedStartTime)) || !ISO_DATETIME.test(String(schedEndTime))) {
        RESTResponseMgr.createError(400, 'INVALID_REQUEST', 'Bad Request', 'schedStartTime/schedEndTime must be ISO 8601').render();
        return;
    }
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(email)) || String(email).length > 254) {
        RESTResponseMgr.createError(400, 'INVALID_REQUEST', 'Bad Request', 'Invalid email').render();
        return;
    }

    var subject = typeof body.subject === 'string' ? body.subject : null;
    if (typeof subject === 'string' && subject.length > 255) {
        subject = subject.slice(0, 255);
    }

    var result = schedulerCore.bookAppointment({
        schedStartTime: schedStartTime,
        schedEndTime: schedEndTime,
        email: email,
        b2cCustomerId: b2cCustomerId,
        subject: subject,
        territoryId: typeof body.territoryId === 'string' ? body.territoryId : null,
        workTypeId: typeof body.workTypeId === 'string' ? body.workTypeId : null,
        firstName: firstName,
        lastName: lastName,
        locale: locale
    });

    if (!result.ok) {
        renderError(result.code);
        return;
    }
    log.info('appointment booked sa={0}', result.serviceAppointmentId);
    var successBody = { success: true, serviceAppointmentId: result.serviceAppointmentId };
    if (result.assignedResourceId) {
        successBody.assignedResourceId = result.assignedResourceId;
    }
    RESTResponseMgr.createSuccess(successBody).render();
};
exports.createAppointment.public = true;

/**
 * GET /custom/sfnext-appointment/v1/territories
 *
 * Returns active ServiceTerritory records, optionally filtered by c_siteId.
 */
exports.getServiceTerritories = function () {
    var schedulerCore = require('*/cartridge/scripts/helpers/schedulerCore');

    var siteId = paramString('c_siteId');
    var result = schedulerCore.getServiceTerritories({ siteId: siteId || undefined });
    if (!result.success) {
        renderError(result.error && result.error.code ? result.error.code : 'SCHEDULER_UNAVAILABLE');
        return;
    }
    RESTResponseMgr.createSuccess({ territories: result.territories }).render();
};
exports.getServiceTerritories.public = true;

/**
 * GET /custom/sfnext-appointment/v1/work-types
 *
 * Returns WorkTypes for the given territory (via WorkTypeGroup), or falls back to
 * the site-pref workTypeGroupId.
 */
exports.getWorkTypes = function () {
    var schedulerCore = require('*/cartridge/scripts/helpers/schedulerCore');

    var territoryId = paramString('c_territoryId');
    var result = schedulerCore.getWorkTypes({ territoryId: territoryId || undefined });
    if (!result.success) {
        renderError(result.error && result.error.code ? result.error.code : 'SCHEDULER_UNAVAILABLE');
        return;
    }
    RESTResponseMgr.createSuccess({ workTypes: result.workTypes }).render();
};
exports.getWorkTypes.public = true;

/**
 * GET /delivery-availability
 * Returns available delivery slots for the given territory + work-type group.
 * Reuses the same schedulerCore.getAvailability helper as appointment availability.
 */
exports.getDeliverySlotAvailability = function () {
    var schedulerCore = require('*/cartridge/scripts/helpers/schedulerCore');
    var customer = session.customer;
    if (!customer || !customer.isAuthenticated()) {
        RESTResponseMgr.createError(401, 'SCHEDULER_AUTHORIZATION', 'Unauthorized', 'A registered shopper session is required').render();
        return;
    }

    var startTime = paramString('c_startTime');
    var endTime = paramString('c_endTime');
    var territoryId = paramString('c_territoryId');
    var workTypeGroupId = paramString('c_workTypeGroupId');

    var result = schedulerCore.getAvailability({
        startTime: startTime,
        endTime: endTime,
        territoryId: territoryId || undefined,
        workTypeGroupId: workTypeGroupId,
        isDelivery: true
    });
    if (!result.success) {
        renderError(result.error && result.error.code ? result.error.code : 'SCHEDULER_UNAVAILABLE');
        return;
    }
    RESTResponseMgr.createSuccess({ success: true, slots: result.slots, timezone: result.timezone }).render();
};
exports.getDeliverySlotAvailability.public = true;

/**
 * POST /delivery-slots
 * Reserves a delivery slot by creating a ServiceAppointment in Core.
 * Reuses bookAppointment helper; slot hold counters from W-24902251 apply.
 */
exports.reserveDeliverySlot = function () {
    var schedulerCore = require('*/cartridge/scripts/helpers/schedulerCore');
    var customer = session.customer;
    if (!customer || !customer.isAuthenticated()) {
        RESTResponseMgr.createError(401, 'SCHEDULER_AUTHORIZATION', 'Unauthorized', 'A registered shopper session is required').render();
        return;
    }
    var b2cCustomerId = customer.ID;
    var body = JSON.parse(request.httpParameterMap.requestBodyAsString);

    var schedStartTime = body.schedStartTime;
    var schedEndTime = body.schedEndTime;
    var email = (customer.profile && customer.profile.email) ? String(customer.profile.email) : body.email;

    if (!ISO_DATETIME.test(String(schedStartTime)) || !ISO_DATETIME.test(String(schedEndTime))) {
        RESTResponseMgr.createError(400, 'INVALID_REQUEST', 'Bad Request', 'schedStartTime/schedEndTime must be ISO 8601').render();
        return;
    }
    if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(email)) || String(email).length > 254) {
        RESTResponseMgr.createError(400, 'INVALID_REQUEST', 'Bad Request', 'Invalid email').render();
        return;
    }

    var subject = typeof body.subject === 'string' ? body.subject : null;
    if (typeof subject === 'string' && subject.length > 255) {
        subject = subject.slice(0, 255);
    }

    var result = schedulerCore.bookAppointment({
        schedStartTime: schedStartTime,
        schedEndTime: schedEndTime,
        email: email,
        b2cCustomerId: b2cCustomerId,
        subject: subject,
        territoryId: body.territoryId || undefined,
        workTypeId: body.workTypeId || undefined,
        isDelivery: true
    });

    if (!result.success) {
        var code = result.error && result.error.code ? result.error.code : 'SCHEDULER_UNAVAILABLE';
        if (code === 'SCHEDULER_SLOT_TAKEN') {
            RESTResponseMgr.createError(409, 'SCHEDULER_SLOT_TAKEN', 'Conflict', 'Slot no longer available').render();
        } else {
            renderError(code);
        }
        return;
    }
    RESTResponseMgr.createSuccess({
        success: true,
        serviceAppointmentId: result.serviceAppointmentId,
        assignedResourceId: result.assignedResourceId
    }).render();
};
exports.reserveDeliverySlot.public = true;
