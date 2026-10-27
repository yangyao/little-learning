#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 scripts/generate-tests.py
"${JAVA_HOME:+$JAVA_HOME/bin/}javac" -encoding UTF-8 -d build/tests app/src/main/java/com/family/littlelearning/GameModel.java build/tests/ContentFixtures.java tests/RulesTest.java
"${JAVA_HOME:+$JAVA_HOME/bin/}java" -cp build/tests com.family.littlelearning.RulesTest
