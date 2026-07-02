#!/usr/bin/env bash
# Validate the shape of an app-configuration/tasksList.json file.
#
# Usage: validate-tasks-list.sh <path-to-tasksList.json>
#
# Exit codes:
#   0 - file is valid
#   1 - file is invalid (errors printed to stderr)
#   2 - usage error (bad args or unreadable file)
#
# Schema:
#   - Top-level must be a non-empty JSON array.
#   - Each entry is an object with:
#       Required: taskKey (string, ^[a-z][a-z0-9_]*$, unique per file),
#                 name (non-empty string),
#                 description (non-empty string),
#                 taskNumber (non-empty string, sequential from "1").
#       Optional: link (string, may be empty).

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") <path-to-tasksList.json>" >&2
  exit 2
fi

file="$1"

if [[ ! -f "$file" ]]; then
  echo "File not found: $file" >&2
  exit 2
fi

if ! jq empty "$file" 2>/dev/null; then
  echo "tasksList.json is not valid JSON" >&2
  exit 1
fi

if ! jq -e 'type == "array" and length > 0' "$file" >/dev/null 2>&1; then
  echo "tasksList.json must be a non-empty JSON array" >&2
  exit 1
fi

errors="$(jq -r '
  [to_entries[] |
   .key as $idx |
   .value as $task |
   (
     if ($task | type) != "object" then
       "Item at index \($idx): must be an object"
     elif ($task.taskKey | type) != "string" or ($task.taskKey | length) == 0 then
       "Item at index \($idx): \"taskKey\" is required and must be a non-empty string"
     elif ($task.taskKey | test("^[a-z][a-z0-9_]*$")) | not then
       "Item at index \($idx): \"taskKey\" must match ^[a-z][a-z0-9_]*$ (snake_case, got \"\($task.taskKey)\")"
     elif ($task.name | type) != "string" or ($task.name | length) == 0 then
       "Item at index \($idx): \"name\" is required and must be a non-empty string"
     elif ($task.description | type) != "string" or ($task.description | length) == 0 then
       "Item at index \($idx): \"description\" is required and must be a non-empty string"
     elif ($task.taskNumber | type) != "string" or ($task.taskNumber | length) == 0 then
       "Item at index \($idx): \"taskNumber\" is required and must be a non-empty string"
     elif $task.taskNumber != ($idx + 1 | tostring) then
       "Item at index \($idx): \"taskNumber\" must be \"\($idx + 1)\" (got \"\($task.taskNumber)\")"
     elif ($task | has("link")) and (($task.link | type) != "string") then
       "Item at index \($idx): \"link\" must be a string when present"
     else
       empty
     end
   )] | join("\n")
' "$file" 2>/dev/null)"

if [[ -n "$errors" ]]; then
  echo "tasksList.json structure validation failed:" >&2
  printf '%s\n' "$errors" >&2
  exit 1
fi

duplicate_keys="$(jq -r '
  [.[].taskKey] | group_by(.) | map(select(length > 1) | .[0]) | join(", ")
' "$file" 2>/dev/null)"
if [[ -n "$duplicate_keys" ]]; then
  echo "tasksList.json has duplicate taskKey values: $duplicate_keys" >&2
  exit 1
fi

count="$(jq 'length' "$file")"
echo "tasksList.json is valid ($count task(s))"
exit 0
