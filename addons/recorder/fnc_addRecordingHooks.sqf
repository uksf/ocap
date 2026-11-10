/* ----------------------------------------------------------------------------
FILE: fnc_addRecordingHooks.sqf

FUNCTION: OCAP_recorder_fnc_addRecordingHooks

Description:
  Installs every recording-only handler, loop, and client hook the first time recording starts. Until then, OCAP adds no per-frame, per-unit, per-marker, or per-shot work on the server, headless clients, or players. Runs once per mission. Called by <OCAP_recorder_fnc_startRecording>.

Parameters:
  None

Returns:
  Nothing

Examples:
  > call FUNC(addRecordingHooks);

Public:
  No

Author:
  IndigoFox, Dell, UKSF
---------------------------------------------------------------------------- */
#include "script_component.hpp"

if (!isNil QGVAR(recordingHooksAdded)) exitWith {};
GVAR(recordingHooksAdded) = true;

if (isNil QEGVAR(EH,EntityKilled)) then {
  // Event Handler: OCAP_EH_EntityKilled
  // Handle for the "EntityKilled" mission event handler. Fired when an entity is killed. Calls <OCAP_recorder_fnc_eh_killed>.
  EGVAR(EH,EntityKilled) = addMissionEventHandler ["EntityKilled", {
    _this call FUNC(eh_killed);
  }];
  OCAPEXTLOG(["Initialized EntityKilled EH"]);
};

if (isNil QEGVAR(EH,EntityRespawned)) then {
  // Event Handler: OCAP_EH_EntityRespawned
  // Handle for the "EntityRespawned" mission event handler. Fired when an entity is respawned. Sets new body to not-killed and calls <OCAP_recorder_fnc_addUnitEventHandlers> on it. Then excludes corpse from further capture.
  EGVAR(EH,EntityRespawned) = addMissionEventHandler ["EntityRespawned", {
    params ["_entity", "_corpse"];

    _entity setvariable [QGVARMAIN(isKilled), false];

    // Skip when entity == corpse (respawnOnStart reuses the same object)
    if (_corpse getVariable [QGVARMAIN(isInitialized), false]) then {
      if (_entity != _corpse) then {
        [":SOLDIER:DELETE:", [
          _corpse getVariable [QGVARMAIN(id), -1],
          GVAR(captureFrameNo)
        ]] call EFUNC(extension,sendData);
        _corpse setVariable [QGVARMAIN(exclude), true];
        if (!isNil QGVAR(trackedUnits)) then {
          GVAR(trackedUnits) deleteAt (_corpse getVariable [QGVARMAIN(id), -1]);
        };
      };

      [_entity, true] spawn FUNC(addUnitEventHandlers);
    };
  }];
  OCAPEXTLOG(["Initialized EntityRespawned EH"]);
};

if (isNil QEGVAR(listener,markers)) then {
  call FUNC(handleMarkers);
};

call FUNC(trackSectors);

if (isClass (configFile >> "CfgPatches" >> "ace_advanced_throwing")) then {
  if (isNil QEGVAR(listener,aceThrowing)) then {
    /*
      CBA Event: ace_advanced_throwing_throwFiredXEH
      Fired when a throwable is primed. This is a global event the server will handle and forward to <OCAP_recorder_fnc_eh_firedMan>. Created only if PBO "ace_advanced_throwing" is loaded.
    */
    EGVAR(listener,aceThrowing) = ["ace_advanced_throwing_throwFiredXEH", {
      _this call FUNC(eh_firedMan)
    }] call CBA_fnc_addEventHandler;
    OCAPEXTLOG(["Initialized ACE Throwing listener"]);
  };
};

if (isClass (configFile >> "CfgPatches" >> "ace_explosives")) then {
  if (isNil QEGVAR(listener,aceExplosives)) then {
    /*
      CBA Event: ace_explosives_place
      Event listener for ACE3 global event indicating a mine has been placed and armed. Calls <OCAP_recorder_fnc_aceExplosives> when triggered. Created only if PBO "ace_explosives" is loaded.
    */
    EGVAR(listener,aceExplosives) = ["ace_explosives_place", {
      call FUNC(aceExplosives);
    }] call CBA_fnc_addEventHandler;
    OCAPEXTLOG(["Initialized ACE Explosives listener"]);
  };
};

call FUNC(addEventIntegrations);
call FUNC(eh_fired_server);
call FUNC(telemetryLoop);
[] spawn FUNC(getStaticObjects);

if (isNil QGVAR(entityMonitorsInitialized)) then {
  call FUNC(entityMonitors);
};
