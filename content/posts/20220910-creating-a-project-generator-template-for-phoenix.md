%{
title: "Creating A Project Generator Template For Phoenix",
category: "Programming",
tags: ["elixir","phoenix","template"],
description: "Using mix template and mix generator to create a phoenix blog starter template with liveview and tailwindcss",
published: true
}
---

<!--Using mix_template and mix_generator to create a phoenix blog starter template with liveview and tailwindcss-->

Recently, I started working on a few projects that required me to create a phoenix project with liveview and [tailwindcss](https://tailwindcss.com/); reusing some of the code currently powering this blog content with markdown.

Now I could create a base project and then copy the code over, but I wanted to automate this process. I also wanted to make it easy for others to use this template.

I decided to try using [mix template](https://hexdocs.pm/mix/Mix.Tasks.Template.html) and [mix generator](https://hexdocs.pm/mix/Mix.Tasks.Generator.html) by the amazing [PragDave](https://twitter.com/PragDave) to create my reusable phoenix project template.

## Mix Template and Mix Generator

**Mix Template** is a mix task that allows you to install and manage mix templates; and **Mix Generator** is a mix task that can be used to create new projects from said templates.

Both tools are fairly simple to use and can be installed using the following command:

```bash
$ mix archive.install hex mix_templates
$ mix archive.install hex mix_generator
```

Once installed, they can be used to create a new project from a template or to create a new template. We can validate the tools installed correctly by running the following commands:

```bash
mix template.hex
```

Which should return a list of available templates, like:

```bash
Templates on hex.pm

gen_template_project:
    A replacement for `mix new «project»` that generates files which
    I believe to be easier to read and maintain.

gen_template_ecto_service:
    A template `mix gen ecto_service «project»` that generates
    a project for building stand alone ecto services (using Posgres)

gen_template_umbrella:
    Generate a basic umbrella project.
```