from synapse.module_api import ModuleApi
from synapse.api.errors import SynapseError
from synapse.api.constants import EventTypes

class EnforceNoE2EE:
    def __init__(self, config, api: ModuleApi):
        self.api = api

        # Hook room creation
        api.register_third_party_rules_callbacks(
            on_create_room=self.on_create_room,
            on_new_event=self.on_new_event,
        )

    async def on_create_room(self, requester, config, is_requester_admin):
        """
        Intercept room creation and strip encryption state.
        """

        initial_state = config.get("initial_state", [])

        # Remove any m.room.encryption state events
        config["initial_state"] = [
            event for event in initial_state
            if event.get("type") != EventTypes.RoomEncryption
        ]

        return True  # allow room creation

    async def on_new_event(self, event, state_events):
        """
        Block any attempt to enable encryption in an existing room.
        """

        if event.type == EventTypes.RoomEncryption:
            raise SynapseError(
                403,
                "Encryption is disabled on this server.",
                errcode="M_FORBIDDEN",
            )

        return True
