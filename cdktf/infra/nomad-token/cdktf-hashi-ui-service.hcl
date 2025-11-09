# --------------------------------------------------------------------------------
#  Hashi-UI — Nomad Client Token (CDKTF-managed)
#
#  Purpose:
#    Mint a Nomad client token for Hashi-UI, bound to the policy that grants
#    read-only access across nodes, agent, operator, and namespaces.
#
#  Notes:
#    - The CDKTF helper registers tokens by filename, assigning the policy
#      named after this file's basename ("cdktf-hashi-ui-service") to the token.
#    - Keeping Policies below consistent with the filename makes this future-proof
#      even if the helper evolves to parse content.
# --------------------------------------------------------------------------------

Name     = "hashi-ui"
Type     = "client"
Policies = ["cdktf-hashi-ui-service"]

