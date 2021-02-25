%{
title: "Magento and HHVM",
category: 'Programming',
tags: ['php','programming'],
description: "If you are developer or system administrator working with Magento running one or more medium sized stores, chances are that you are familiar with the many challenges of optimizing and scaling Magento."
}
---

If you are developer or system administrator working with **Magento** running one or more medium sized stores, chances are that you are familiar with the many challenges of optimizing and scaling Magento.

**Magento** is (in)famous for its performance, specially when scaling to a large numbers products, transactions or even catalog rules, seasoned Magento developers have probably hit at least one of this performance bottle necks more than once.

From the sysAdmin perspective, **Magento** can be a beast eating away resources and with many bottlenecks and paths to solve them:

- Database Optimization
- Cache Optimization and Architecture
- Apache vs Nginx
- mod_php or php-fpm
- OPCode Caching

And while all the optimizations help, in the end there is a major performance bottleneck that is not as easily surpassed and that is PHP performance, since PHP is an interpreted language there is price to pay in terms of speed of execution and overall performance.

As large PHP like **Magento** try to scale, this performance price gets more noticeable and harder to solve, sure we can always throw more hardware, setup load balancing and fire up a reverse proxy cache; but that will only mask the issue.

## HHVM

Facebook, believe it or not; is runs on PHP and of course it had to deal with the same problems that we talked about before. To solve them Facebook took and interesting approach by creating **HHVM** (HipHop Virtual Machine).

> **HHVM** (HipHop Virtual Machine) converts PHP code into a high-level bytecode (commonly
> known as an intermediate language). This bytecode is then translated into x64 machine
> code dynamically at runtime by a just-in-time (JIT) compiler. In these respects, **HHVM**
> has similarities to virtual machines for other languages including C#/CLR and Java/JVM.

According to Facebook, they have seen between 6x to 9x the improvement on the performance and speed of their servers, this is big news for any PHP application and not only **Magento**.Having Magento run on **HHVM** would drastically improve the speed and performance of the actual application without relying solely on caching.

Currently, there are still many bugs on certain parts of the **HHVM** libraries that prevent **Magento** from fully running. However a lot of progress has been made recently to solve many of these issues; right now the main force behind all the bug fixes to get Magento and HHVM running is Daniel Sloof.

<!-- Daniel Sloof profile and contact information -->

> Daniel Sloof is a **Magento** Developer located in Netherlands; has worked with Magent since 2010 and can be contacted at daniel@rubic.nl or on twitter @daniel_sloof

Daniel has been working for the last few months on **HHVM** and OSX compatibly, as well as the HHVM issues with simple_xml.

As the time of this article publication, Magento can run on HHVM, but should still be approached with caution for production environments.

## Getting Things Up And Running

So you want to run **Magento** on top of **HHVM**? If that's the case you're in luck, let's walkthrough the process for setting up, installing and running Magento+HHVM.

<div class="notice notice-warning">
	<strong>Notice:</strong> While the advantages for running <strong>Magento</strong> on <strong>HHVM</strong> are many, HHVM is still under heavy development for that reason I would advise caution when running production projects on HHVM.
</div>

### Installing HHVM

To run **HHVM** we will have to compile from the source, since HHVM is still under active and heavy development this is the best way to guarantee that we will get the latest and greatest version.

<div class="notice notice-warning">
	This article is not a detailed walkthrough for installing HHVM, if you get stuck or want to learn more read <a href="https://coderoncode.com/2013/07/27/first-steps-on-hhvm.html">First steps on HHVM</a> or additional you can visist <a href="https://github.com/facebook/hhvm/wiki#building-hhvm">HHVM Wiki</a> for environment specific instructions.
</div>

We will need to get a copy of the **HHVM** repository:

<!-- Instructions for cloning the github project or downloading the zip -->

<script src="https://gist.github.com/amacgregor/8898050.js"></script>

Next we will need to configure and compile **HHVM**:

<!-- Compilation instructions go here -->

<script src="https://gist.github.com/amacgregor/8898057.js"></script>

## Testing HHVM

At this point we have a working hhvm binary that we can use to run php scripts, let's verify that our hhvm instance works by running, execute the following command:

```
$ /path/to/my/installation/hhvm/hphp/hhvm/hhvm --help
```

If everything is working correctly we should see the following output:

<script src="https://gist.github.com/amacgregor/9056531.js"></script>

Now if you want to be able to run **HHVM** easily from any location you can add it to the **PATH** by creating a symlink:

```
$ ln -s /path/to/my/install/hhvm/hphp/hhvm/hhvm /usr/bin/hhvm
```

## Configuring HHVM for Magento

The next step will be setting up the basic configuration file for **HHVM** and running our first test:

<script src="https://gist.github.com/amacgregor/0b7dd1f25e976b12713c.js"></script>

<!-- Instructions for **HHVM** .hdf configuration -->

> **HHVM** works around .hdf configuration files, HDF stands for **Hierarchical Data File** although in my opinion **Hiphop Definition File** would also make sense.

The definition files contain all the configuration for a specific **HHVM** instance they are somewhat equivalent to the apache configuration files. Most of the settings will be self explanatory, however I think it would be helpful if we breakdown the each of the configuration settings and we go into detail.

As we can see in the example file, there are 4 main configuration nodes:

- Server
- Eval
- VirtualHost
- StaticFile

<!-- Settings Breakdown section -->

#### Server

The server node contains configuration that is specifically used when hhvm runs in server mode (surprising I know!), among these settings we have options like port, listening ip, hostname, number of threads to spawn and so on.

The are 2 settings to which we should pay particular attention for our **Magento** installation, **SourceRoot** and **DefaultDocument**.

- **SourceRoot** allows us to specify the **Magento** root folder, this would be the equivalent of Apache **DocumentRoot**.
- **DefaultDocument** allow us to set the index file to be used automatically, this would be the equivalent of Apache **DirectyIndex**.

#### Eval

The Eval node controls the JIT(Just In Time) Compiler settings in this case the only thing that we need to know is that it should be enabled to get the full benefits from H**HHVM**.

#### VirtualHost

The Virtual host node allows us to set certain settings by virtual host like **ServerName** and **ServerVariables** in this specific case we need to set the rewrite rules to work with **Magento** rewrite settings, in order to resolve the assets and urls correctly.

#### StaticFile

The StaticFile node as the name describes allow us to configure how **HHVM** will handle and server files like css, js and image files.

Now, that we have a working configuration file we can run our first test on **HHVM**.

### Running **Magento** with **HHVM**

Finally, we can get **Magento** up and running with **HHVM**, let's start HHVM using the following command:

<!-- Insert Command for running hhvm -->

```
$ hhvm -m server -c example.hdf
```

At this point, we should see our Magento website if we go to **https://localhost/**.

### Measuring the Speed

Finally, let's run a quick speed test with siege and compare the speeds of **HHVM** built-in server VS Apache2 + PHP-fpm:

#### Apache2 and PHP-FPM

```
$ siege -c20 -t1m localhost
** SIEGE 3.0.1
** Preparing 20 concurrent users for battle.
The server is now under siege...
Lifting the server siege...      done.

Transactions:                436 hits
Availability:             100.00 %
Elapsed time:              59.14 secs
Data transferred:           1.89 MB
Response time:              2.14 secs
Transaction rate:           7.37 trans/sec
Throughput:                 0.03 MB/sec
Concurrency:               15.77
Successful transactions:     436
Failed transactions:           0
Longest transaction:        3.06
Shortest transaction:       0.51

```

#### **HHVM** Build In Server

```
$ siege -c20 -t1m localhost
** SIEGE 3.0.1
** Preparing 20 concurrent users for battle.
The server is now under siege...
Lifting the server siege...      done.

Transactions:               1950 hits
Availability:             100.00 %
Elapsed time:              59.96 secs
Data transferred:           9.32 MB
Response time:              0.13 secs
Transaction rate:          32.52 trans/sec
Throughput:                 0.16 MB/sec
Concurrency:                4.17
Successful transactions:    1950
Failed transactions:           0
Longest transaction:        0.47
Shortest transaction:       0.07

```

<div class="notice notice-warning">
    <strong>Notice:</strong> The previous tests are by no means comprehensive or accurate, and more than anything they try to showcase the speed difference between the two setups.
</div>

## Summary

<!--
yeah but using inbuilt webserver is wrong because:
1) it will be deprecated in the foreseeable future.
2) you can keep using all of your existing rewrites etc because you're just changing the cgi backend.
3) static assets are served faster somethign like nginx.
-->

We covered a lot of ground here, and we learned how to get **Magento** up and running with **HHVM** Built-in server, that being said I feel that is important that we clarify a few things.

While this article uses the hhvm built-in server, it is important to note that it is not the recommended method of using **HHVM**. For production setups, Apache/Nginx + **FastCGI** + HHVM is the recommended setup. Here are some of the reasons why FastCGI should be the prefered method:

- The Built-in webserver will be eventually deprecated.
- You can keep using all the existing rewrites.
- Static assests are served slightly faster by something like Apache or Nginx.

However, for the scope of this article and learning purposes the built-in server is a good introduction to HHVM and the general setup and configuration, in a further article we will cover the production setup with **FastCGI**
