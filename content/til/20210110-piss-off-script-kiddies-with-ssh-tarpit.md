%{
title: "Piss-off script kiddies with SSH Tarpit",
category: "Devops",
tags: ["devops","ssh","hacking"],
description: "SSH tarpits are a thing to waste the time of automated scanners."
}    
---

<!--SSH tarpits are a thing to waste time from automated scanners-->

[Endlessh](https://github.com/skeeto/endlessh) is an SSH tarpit that very slowly sends an endless, random SSH banner. It keeps SSH clients locked up for hours or even days at a time. The purpose is to put your real SSH server on another port and then let the script kiddies get stuck in this tarpit instead of bothering a production server.

There are many types of Tarpits by definition Tarpits are network services that intentionally insert delays in the protocol, slowing down clients by forcing them to wait.

```bash
git clone git@github.com:skeeto/endlessh.git
cd endlessh
make && make install
```

And now run it:

```bash
endlessh -v >endlessh.log 2>endlessh.err
```

### References:

- [Endlessh](https://github.com/skeeto/endlessh)
