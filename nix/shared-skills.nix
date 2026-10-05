{ pkgs, inputs }:
let
  inherit (pkgs) lib;
  agentSkills = import (inputs.agent-skills-nix.outPath + "/lib") {
    inherit lib inputs;
  };
  sources = {
    matt = {
      path = inputs.matt-skills;
      subdir = "skills";
    };
    humanlayer = {
      path = inputs.humanlayer-skills;
      subdir = "plugins/show-me/skills/show-me";
    };
  };
  mattSkillPaths = {
    ask-matt = "engineering/ask-matt";
    codebase-design = "engineering/codebase-design";
    code-review = "engineering/code-review";
    diagnosing-bugs = "engineering/diagnosing-bugs";
    domain-modeling = "engineering/domain-modeling";
    grilling = "productivity/grilling";
    grill-me = "productivity/grill-me";
    grill-with-docs = "engineering/grill-with-docs";
    handoff = "productivity/handoff";
    implement = "engineering/implement";
    implement-spec = "engineering/implement-spec";
    improve-codebase-architecture = "engineering/improve-codebase-architecture";
    pr = "engineering/pr";
    prototype = "engineering/prototype";
    research = "engineering/research";
    retro = "engineering/retro";
    setup-matt-pocock-skills = "engineering/setup-matt-pocock-skills";
    tdd = "engineering/tdd";
    teach = "productivity/teach";
    to-questionnaire = "productivity/to-questionnaire";
    to-spec = "engineering/to-spec";
    to-tickets = "engineering/to-tickets";
    triage = "engineering/triage";
    "wait-what" = "productivity/wait-what";
    wayfinder = "engineering/wayfinder";
    wizard = "engineering/wizard";
    writing-for-agents = "productivity/writing-for-agents";
  };
  catalog = agentSkills.discoverCatalog sources;
  explicitSkills =
    lib.mapAttrs (name: path: {
      from = "matt";
      inherit path;
    }) mattSkillPaths
    // {
      show-me = {
        from = "humanlayer";
        path = ".";
      };
    };
  selection = agentSkills.selectSkills {
    inherit catalog sources;
    skills = explicitSkills;
  };
  bundle = agentSkills.mkBundle {
    inherit pkgs selection;
    name = "ai-setup-shared-skills";
  };
  paths = lib.mapAttrs (name: _: "${bundle}/${name}") selection;
in
{
  inherit
    bundle
    catalog
    paths
    selection
    ;
}
