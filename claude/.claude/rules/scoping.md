Scope work by what the problem needs. A feature or refactor ships as one PR,
however much code it touches and including the follow-up fixes found along the
way, because one PR is easier to dogfood and test as a whole and no merge in
between leaves the product half-done. Propose a split only for a genuine
operational reason, such as a repository boundary, a migration that must land
first, or a merged first PR that unblocks other work, and name that reason.

Judge designs by what is right for the problem, not by effort or time to build,
and leave out timelines and ETAs unless asked. Propose the proper fix first;
scope to the smallest safe fix only when the user calls it a hotfix.
