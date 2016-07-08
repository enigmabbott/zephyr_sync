# zephyr_sync

Zephyr test cases do not import easily into JIRA. Here lies a sweet of
commands which facilite the creation, deletion, syncing, and validation of
test cases between 2 instances.

I supposed you could also use this as an import tool with some minor
refactoring.

Built and tested with Perl (v5.20.2)

Requires Moose;

RESTWrap.pm is my Moosified version of cpan's Rest::Client.pm (which you swap
out if you wish)

