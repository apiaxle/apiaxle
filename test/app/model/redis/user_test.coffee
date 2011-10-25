{ GatekeeperTest } = require "../../../gatekeeper"

class exports.UserTest extends GatekeeperTest
  "test initialisation happened": ( done ) ->
    @ok @gatekeeper
    @ok model = @gatekeeper.model "user"

    @equal model.ns, "gatekeeper:test:user:"

    done 2
