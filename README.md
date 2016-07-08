# zephyr_sync

Zephyr test cases do not import easily into JIRA. Here lies a sweet of
commands which facilitate the creation, deletion, syncing, and validation of
test cases between 2 instances.

I supposed you could also use this as an import tool with some minor
refactoring.
Built and tested with Perl (v5.20.2)

Requires JIRA plugin: ZAPI (sadly a paid plugin)
https://marketplace.atlassian.com/plugins/com.thed.zephyr.zapi/server/overview

Requires Moose;

RESTWrap.pm is my Moosified version of cpan's Rest::Client.pm (which you can swap
out if you wish)

