%{
title: "Vim Is The Perfect IDE",
category: "Programming",
tags: ['programming','vim','tooling','productivity'],
description: "I have have tried Atom, SublimeText, TextMate, Eclipse, Visual Studio, and most of the Jetbrains products, I'm constantly tweaking and looking for a better setup, however Vim always feels like home to me; and I'm to the point now where I rarely use IDEs – exception being messy and complex projects where IDEs can do a lot of heavily lifting"
}
---

Over the years I've jumped back and forth between many code editors, **IDEs** and **tools**; but it seems that somehow I always end up coming right back to VIM, and not only for programming – guess which markdown editor I'm using to write this post.

I've have tried Atom, SublimeText, TextMate, Eclipse, Visual Studio, and most of the Jetbrains products, I'm constantly **tweaking and looking for a better setup**, however Vim always feels like home to me; and I'm to the point now where I rarely use IDEs – exception being messy and complex projects where IDEs can do a lot of heavily lifting (yes, Magento I'm talking about you.)

But other than that Vim is my default Ruby, Elixir, Python, PHP IDE and as well the main tool that I use for writing drafts and books.

## What it look like

![What it looks like](https://i.imgur.com/AQSIXwj.gif)

## The Setup

So how does this magical tool work? Is all out of the box right? right? Well no, as with all the worthwhile things in life there is a bit of effort involved on getting the Vim setup just like I wanted it. Fortunately, is far from custom and is mostly the right combination of plugins.

You can find my current Vim configuration and dot files in its corresponding [Github repository](https://github.com/amacgregor/dot-files) feel free to fork it and give a shot.

We are in particular interested in the vimrc file, let's break it down:

<script src="https://gist.github.com/amacgregor/0467f99e0e75725f57682ccd1f2189fb.js"></script>

Each plugin in this setup is separated in the following categories:

### Utility

This kind of a miscellaneous category and is comprised of plugins used to enhance or change the behaivour of core vim; the most useful important ones are:

- **Nerdtree**: It gives you easy access to the file system in the form of a directory tree on the left side of the screen, as well provides shortcuts for filesystem manipulation(create, delete, move files and directories)
- **Tagbar**: Quick tag browser for the current file, a must have if you are using any kind of **ctags** like exuberant-tags.
- **FZF**: Fuzzy finder, another handy utility for finding files and commands.
- Neocomplete: Vim Autocomplete on steroids.

### Generic Programming Support

These plugins fall directly on the category of programming and are used my all or most of the **programming languages** that I currently have setup:

- **Exuberant-Ctags**: tags are named definitions of classes, functions, abstract types and so on; adding support to Vim gives you some of that 'magic' IDE code navigation functionality.
- **Syntastic**: THE syntax checking plugin for Vim, if you are familiar with the way that code inspections work on Jetbrains and similar IDEs, syntastic will make feel right at home.
- **Vim-autoclose**: Automatically closes a character that could/should have a matching closing counterpart, like () "" [] {} and so on.

### Markdown/Writing

As I mentioned Vim is my go to editor for drafting new posts be it books, blogs or random angry letters. From this particular section only language tools deserves a special shot-out as it makes for a great Grammar checker directly from inside Vim.

### Erlang/Elixir/PHP/Elm Support

When it comes down to the **individual language support** there isn't really much to highlight other than I've tried (and somewhat failed) to keep the plugins to a minimum and focus only on the **essential language support**.

So far elixir is winning the battle in terms of plugins as I've added additional functionality like the ability to run tests and generate content from inside Vim, I have yet to decide if I'm keeping all the plugins for it.

### Git Support

Standard git support that I'm afraid I rarely use, I find myself going directly back to the **shell** and doing the **git workflow** outside of Vim, so I'm open to suggestions and to hear what everyone else is using in terms of setup.

### Themes and Interfaces

Ok this is a big one but mostly because I keep forgetting to remove unused themes and colorschemes, let's highlight the important ones:

- **Vimarline**: Lean and mean status/tabline for Vim; it also looks cool as fuck.
- **Vim-Devicons**: Because not only atom gets all the fancy icons on the sidebar, highly recommended to if you are using nerdtree.

The remaining parts of the configuration file are either plugin configuration or personal key re-mappings that I use for quality of like; I've done my best to document and segment each section so it should be easy enough to understand what each setting is doing.

For anyone getting starting with Vim, I do want to bring special attention to the following:

```vim
" Disable arrow movement, resize splits instead.
if get(g:, 'elite_mode')
	nnoremap <Up>    :resize +2<CR>
	nnoremap <Down>  :resize -2<CR>
	nnoremap <Left>  :vertical resize +2<CR>
	nnoremap <Right> :vertical resize -2<CR>
endif
```

As there is no quickest way to force one-self to use the home row for navigation.

# Final Remarks

I hope that for some of you this post has been helpful for some, and I'm far from done with my current setup, in that sense this is **very much a toy** that I continue playing on a nearly daily basis; now that being said and in order to get back to the original premise of the post; it is indeed a very powerful toy, specially when combined with other tools like **Tmux**, here is a sneak peak of my **Elixir** 'IDE' powered by **Vim** and **Tmux**:

![Final remarks](https://i.imgur.com/vI0KjXB.gif)

If you want to know more about my setup, or want to **share yours** please leave a comment below.
