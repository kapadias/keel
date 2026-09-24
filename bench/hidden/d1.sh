#!/usr/bin/env bash
grep -qiE '<input[^>]*type="date"' web/index.html && [ ! -e package.json ] && [ ! -d node_modules ] && [ ! -e web/package.json ]
