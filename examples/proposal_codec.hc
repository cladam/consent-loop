import "../src/proposal_hml"

fun sample_hml() : string {
  "#hml 0.3\n" +
  "#text: amendment\n" +
  "#namespace decision: \"https://hica.dev/schemas/decision/v1\"\n" +
  "@proposal(id: \"DEMO-001\", version: \"1.0\", status: \"submission\") \{\n" +
  "  title: \"Demonstrate the ConsentLoop codec\"\n" +
  "  created: 2026-10-18T09:00:00Z\n" +
  "  cooling-period: 24h\n" +
  "  @body \{\n" +
  "    Decode this proposal and emit canonical HML.\n" +
  "  \}\n" +
  "  @participants \{\n" +
  "    @participant(user: \"alex\", level: 2)\n" +
  "  \}\n" +
  "  @references\n" +
  "  @history \{\n" +
  "    @revision(version: \"1.0\", event: \"submitted\", timestamp: 2026-10-18T09:00:00Z)\n" +
  "  \}\n" +
  "\}"
}

fun main() {
  match decode_proposal(sample_hml()) {
    Err(ProposalSyntaxError(message)) => eprintln("syntax error: " + message),
    Err(ProposalValidationError(message)) => eprintln("validation error: " + message),
    Ok(proposal) => println(encode_proposal(proposal))
  }
}
