from synapse.module_api import ModuleApi
from synapse.types import StateMap
from synapse.events import EventBase


class BlockEncryptionModule:
    def __init__(self, config, api: ModuleApi):
        self.api = api
        api.register_third_party_rules_callbacks(
            check_event_allowed=self.check_event_allowed
        )

    async def check_event_allowed(
        self,
        event: EventBase,
        state_events: StateMap[EventBase],
    ):
        # Block any attempt to enable encryption in a room
        if event.type == "m.room.encryption":
            return False, {
                "errcode": "M_FORBIDDEN",
                "error": "Encrypted rooms are not permitted on this server."
            }

        return True, None
