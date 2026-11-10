/* ----------------------------------------------------------------------------
FILE: fnc_removeRecordingHooks.sqf

FUNCTION: OCAP_recorder_fnc_removeRecordingHooks

Description:
  Removes every recording-only handler, loop, and client hook that <OCAP_recorder_fnc_addRecordingHooks> installed, on the server, headless clients, and players, and clears their JIP queue entries. After this, OCAP runs nothing until recording starts again. Called by <OCAP_recorder_fnc_stopRecording>.

Parameters:
  None

Returns:
  Nothing

Examples:
  > call FUNC(removeRecordingHooks);

Public:
  No

Author:
  UKSF
---------------------------------------------------------------------------- */
#include "script_component.hpp"

if (isNil QGVAR(recordingHooksAdded)) exitWith {};
GVAR(recordingHooksAdded) = nil;

if (!isNil QGVAR(PFHObject)) then {
  [GVAR(PFHObject)] call CBA_fnc_deletePerFrameHandlerObject;
  GVAR(PFHObject) = nil;
};

{
  missionNamespace setVariable [_x, nil];
} forEach [
  QEGVAR(EH,EntityKilled),
  QEGVAR(EH,EntityRespawned),
  QEGVAR(listener,markers),
  QEGVAR(listener,aceThrowing),
  QEGVAR(listener,aceExplosives),
  QGVAR(entityMonitorsInitialized)
];

{
  _x setVariable [QGVAR(sectorTracked), nil];
} forEach (entities "ModuleSector_F");

{
  remoteExec ["", _x];
} forEach [
  "ocap_hooks_markers",
  "ocap_hooks_fired",
  "ocap_hooks_chat",
  "ocap_hooks_aceDeath",
  "ocap_hooks_radio",
  "ocap_hooks_monitors"
];

private _fnc_removeLocalHooks = {
  {
    _x params ["_kind", "_target", "_name", "_id"];
    switch (_kind) do {
      case "mission": { removeMissionEventHandler [_name, _id] };
      case "cba": { [_name, _id] call CBA_fnc_removeEventHandler };
      case "pfh": { [_id] call CBA_fnc_removePerFrameHandler };
      case "object": { if (!isNull _target) then { _target removeEventHandler [_name, _id] } };
      case "scripted": { if (!isNull _target) then { [_target, _name, _id] call BIS_fnc_removeScriptedEventHandler } };
      case "ctrl": { if (!isNull _target) then { _target ctrlRemoveEventHandler [_name, _id] } };
    };
  } forEach (missionNamespace getVariable [QGVARMAIN(hooks), []]);
  GVARMAIN(hooks) = [];

  {
    private _unit = _x;
    {
      _x params ["_event", "_idVar", "_existsVar"];
      private _id = _unit getVariable _idVar;
      if (!isNil "_id") then { _unit removeEventHandler [_event, _id] };
      _unit setVariable [_idVar, nil];
      _unit setVariable [_existsVar, nil];
    } forEach [
      ["FiredMan", QGVARMAIN(firedManEH), QGVARMAIN(firedManEHExists)],
      ["HandleDamage", QGVARMAIN(handleDamageEH), QGVARMAIN(handleDamageEHExists)]
    ];
  } forEach (allUnits + allDeadMen);
};

call _fnc_removeLocalHooks;
_fnc_removeLocalHooks remoteExec ["call", -2];

OCAPEXTLOG(["Removed recording hooks"]);
