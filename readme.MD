# WTD

What The Docker? is a tool to generate a `docker run` command from an already-running container.

## Why?

Because sometimes `bash history` isn't good enough.

## Use

Drop this script into your `$PATH` and invoke via:

`wtd.sh {{running_container_name}} -v`

Where `-v` creates a slightly more verbose output, and may expose secrets if passed through `ENV`.
