#!/bin/bash
npm run build
scp widget/widget.bundle.js* widget/widget.html cometmelogger@azizazt:logs/app/
