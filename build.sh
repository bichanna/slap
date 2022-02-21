#!/bin/bash

echo "Building SLAP..."
nimble build --multimethods:on -d:release --silent
echo "Completed"

exit 0