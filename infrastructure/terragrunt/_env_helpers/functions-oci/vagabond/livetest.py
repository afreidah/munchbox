# -----------------------------------------------------------------------------
# VAGABOND LIVE TEST FUNCTION
# -----------------------------------------------------------------------------
#
# The function vagabond's OCI Functions live tests invoke. It replies under
# vagabond's function contract with exit code 3 and an output naming the
# execution, its args and one env value, so a reply that lost the code or the
# event's contents is caught. Its first arg "sleep" runs it past its timeout.
#
# Author: Alex Freidah / Project: Munchbox
# -----------------------------------------------------------------------------

import io
import json
import time

from fdk import response


def handler(ctx, data: io.BytesIO = None):
    # --- the event: {execution_id, args, env} ---
    event = json.loads(data.getvalue() or b"{}") if data else {}
    args = event.get("args") or []
    env = event.get("env") or {}

    # --- past the 30 second timeout, so OCI ends the run ---
    if args[:1] == ["sleep"]:
        time.sleep(60)

    output = "hello {} [{}] {}\n".format(event.get("execution_id", ""), "|".join(args), env.get("VAGABOND_LIVE", ""))

    return response.Response(
        ctx,
        response_data=json.dumps({"exit_code": 3, "output": output}),
        headers={"Content-Type": "application/json"},
    )
