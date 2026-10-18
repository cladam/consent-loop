pub fun valid_proposal_hml() : string {
  "#hml 0.3\n" +
  "#text: amendment\n" +
  "#namespace decision: \"https://hica.dev/schemas/decision/v1\"\n" +
  "@proposal(id: \"PROP-042\", version: \"1.1\", status: \"refinement\") \{\n" +
  "  title: \"Migrate services to a trunk-based monorepo\"\n" +
  "  created: 2026-06-06T10:00:00Z\n" +
  "  cooling-period: 24h\n" +
  "  @body \{\n" +
  "    Add a mandatory prerequisite for workspace caching.\n" +
  "  \}\n" +
  "  @participants \{\n" +
  "    @participant(user: \"alex\", level: 3)\n" +
  "    @participant(user: \"sofia\", level: 1) \{\n" +
  "      @amendment(target-version: \"1.1\", status: \"adopted\") \{\n" +
  "        Add package-level caching before migration.\n" +
  "      \}\n" +
  "    \}\n" +
  "    @participant(user: \"elias\", level: 2)\n" +
  "  \}\n" +
  "  @references \{\n" +
  "    @ref(type: \"URL\", value: \"https://example.com/issues/104\", description: \"Benchmark\")\n" +
  "  \}\n" +
  "  @history \{\n" +
  "    @revision(version: \"1.0\", event: \"submitted\", timestamp: 2026-06-06T10:00:00Z)\n" +
  "    @revision(version: \"1.1\", event: \"amendment-adopted\", timestamp: 2026-06-06T14:30:00Z) \{\n" +
  "      note: \"Adopted Sofia's caching prerequisite.\"\n" +
  "    \}\n" +
  "  \}\n" +
  "\}"
}
