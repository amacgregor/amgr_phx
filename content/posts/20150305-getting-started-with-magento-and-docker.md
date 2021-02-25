%{
title: "Getting Started With Magento and Docker for Development",
category: 'Programming',
tags: ['magento','programming','docker'],
description: "Setting up a Magento development Environment with docker"
}
---

Docker has taken the DevOps community by storm and is rapidly changing the ecosystem towards distributed architectures, and in case you haven't heard about Docker here is the quick definition:

> Docker is an open platform for developers and sysadmins to build, ship, and run distributed applications.

And while Docker brings amazing things to the table in terms of application architecture, scalability and so on, in this post we are going to use docker to streamline the development pipeline.

## The Problem

If you are reading this article, chances are that you work for a Magento Agency and likely your development flow looks something like this:

- Developers work on local versions of the site and make frequent changes
- Code is pushed to an staging environment for testing
- The staging site is tested, and code is reviewed
- On Approval, the code is merged into a production branch and deployed to production

Based on the flow above, we can say we have at least three environments:

- Local Development
- Staging
- Production

Now, this is an oversimplified workflow, and as soon you start adding CI systems, UAT servers, etc. things start to get more complicated. For now let's stick to our three environments.

Ideally local development and staging should be as close as possible to production as we can, in practice, however, more often than not; there will be big differences.

For example, a large chunk of your developers might be using a solution like MAMP or WAMP, each with its own set of quirks, will likely not match your staging/production. This is where problems start happening, if you ever heard the dreaded phrase "It works on my local" then you know what I'm talking about.

In addition keeping staging in parity with production can have a large overhead, especially if you run multiple architectures, or if your sites have different requirements like php-versions or installing something like IonCube.

## The Solution

This is what adding docker to our development pipeline is all about, being able to have a consistent environment for development, staging, qa and production. For now I will only talk about the first step on our development pipeline, local development.

Running Docker is very much like running virtual machines for local development but with the following advantages:

- Faster creation and initialization
- Lower system footprint
- Easily shareable between developer and environments

To facilitate things, I've created a base docker image that runs a simplified version of server stack I run at **Demac Media** you can find the link at [Docker Hub](https://registry.hub.docker.com/u/amacgregor/base/)

The image will setup apache2.4, php-fpm and and the 4 major versions of Php (5.3,5.4,5.5,5.6) as well create vhost macros for easy setup. Let's take a peak:

<script type="text/javascript" src="https://asciinema.org/a/17314.js" id="asciicast-17314" async></script>

This image is not really meant to be used directly but rather as a base for your projects. The way I would recommend using it is as follows:

In your project base create a folder named docker and add the following file:

**Filename:** Dockerfile

<script src="https://gist.github.com/amacgregor/867b858fafe6b9ab1358.js"></script>

> A Dockerfile is a text document that contains all the commands you would normally execute manually in order to build a Docker image. By calling docker build from your terminal, you can have Docker build your image step by step, executing the instructions successively.

All we are doing above is setting up the vhost for our current project, speaking of which we will need to create said vhost file inside our docker/vhost folder, since we are copying it to our newly created image in the following line

```
COPY config/vhosts/ /etc/apache2/sites-available
```

So let's go ahead and create the file

**Filename:** config/vhosts/localhost.com.conf

<script src="https://gist.github.com/amacgregor/1112523b865211e79240.js"></script>

Wait, that's it? Yes, it's that simple; the example above is using one of the coolest Apache2.4 features, Macros.

The base image has a macro for each of the php versions and as you can see is the first thing we are telling our vhost file to use

```
Use VHost-PHP5.4
```

The values after that are variables to be used by our macro file, in this case:

- $host
- $ip
- $port
- $dir

And while right now we are not using all of them directly, it opens an interesting set of possibilities. We are now ready to build and run our project docker image, but wait what about the project files, well I'm getting to that actually let's go ahead and create a simple test file for our example:

In my case I will create a folder and file example project, in practice we would use our project local repository copy.

**Filename:** ../demac-docker-example/public/index.php

```
<?php phpinfo(); ?>
```

We will also need to create an empty file inside the public folder called **.htaccess-combined**

And now we build our project image:

```
docker build -t amacgregor/localhost_com .
```

Finally we can go ahead and run our newly created image using the following command:

<script src="https://gist.github.com/amacgregor/b391628b2f8aea902a2a.js"></script>

The above might look intimidating at first but let's break it down:

```
-v /home/amacgregor/Projects/DemacMedia/demac-docker-example/public:/srv/www/localhost.com/public_html
```

With this option we are telling Docker to mount a directory from the host filesystem (the one that we just created) into the vhost root directory, this way we can reuse our local project files and test changes on the fly.

```
-p 127.0.0.1:80:80
```

All we are doing here is exposing the port 80 to our host machine port 80, please note that if you have any software like MAMP or Apache already running this won't work and you will need to change the host port.

Finally, we can verify everything is working by loading localhost.com in our browser, if everything worked correctly we should see the PHP information page.

## Feedback

This is the first time I ever worked with docker. Feedback and hints on how to improve are more than welcome. And if you find this useful let me know.
