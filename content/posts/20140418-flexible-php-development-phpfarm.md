%{
title: "Flexible PHP Development with PHPFarm",
category: 'Programming',
tags: ['programming','PHPFarm','PHP'],
description: "Learn how to use PHPFarm to create flexible development environments that can run multiple php versions side by side"
}
---

If you have been working with **PHP** for a while, chances are that you have come across with a project, extension or script that requires to be tested on multiple **PHP** versions, for simple CLI scripts this seems easy enough but what happens when you are working with complex applications, developing for frameworks or multiple versions of them ?

Let's say that like me, a **Magento developer** that regularly develops extensions, there is a need to run on multiple versions of **Magento**. The initial approach that most developers take is to create a virtual machine with the right environment. For an application like Magento that means you need two virtual machines one for PHP5.2 and one for **PHP5.3**.

Or at least that used to be the case because **PHP5.3** is officially being deprecated, now we have to include PHP5.4 into the mix; with out current setup that means creating another virtual machine setting up all our sites again, deploying our changes to each of the virtual machines.

<div class="notice">
<strong>Note:</strong> There are possible workarounds to avoid deploying multiple versions of the code across all servers and sharing the code across all virtual machines but that is outside the scope of this article.
</div>

This setup can quickly become cumbersome and it is not easily scalable: what happens if we want to test individual patch version or test code on all 3 versions, or add PHP5.5 depending of the host machine you use, it might not be able to run more than virtual machine at the same time.

I ran into all these problems while working at [Demac Media](https://www.demacmedia.com/?utm_source=coderoncode.com) where I constantly need to work on multiple environments and specially when testing extensions for commercial distribution. In order to work more efficiently I came up with the following setup than can be ran locally or on a single **Virtual Machine** if you are on windows.

## Meet PHPFarm

Getting multiple **PHP** versions running side by side can be challenging and over the year devs have released multiple solutions like [PHPEnv](https://github.com/phpenv/phpenv) or the new [VirtPHP](https://virtphp.org/), personally I use **PHPFarm** which works very well with my workflow and is extremely easy to use, as well working seamlessly with Apache.

<!-- Brief history about PHPfarm -->

The basic idea behind **PHPFarm** is that we can install several version of PHP side by side, in addition we can select one as current or reference specific version directly. Another extremely nice feature about **PHPFarm** is that we can run patch versions side by side.

## Installation and Configuration

```
$ cd /opt/
$ git clone https://github.com/cweiske/phpfarm.git phpfarm
$ cd phpfarm/src/
```

<div class="notice">
<strong>Note:</strong> In order for PHPFarm to work properly you should add the _/opt/phpfarm/inst/bin_ and _/opt/phpfarm/inst/current-bin_ directories to your path, the method for changing this will vary depending on your current OS.
</div>

So at this point we have everything that we need to install any PHP version, so let's go ahead and install **PHP5.3.0**:

```
$ cd /opt/phpfarm/src/
$ ./compile 5.3.1
```

At this point **PHPFarm** will take care of downloading the source files for the specified version and compiling for our system, while compiling from source might be a little slower than using the distribution binaries, we have much more flexibility over the configuration and options if the installed **PHP** version.

### Configuration

As I mentioned before we can control each individual version compilation options and default _**php.ini**_ settings; both are controller by configuration files inside the **src/** directory.

The default configuration options are in src/options.sh. And we can create version specific option files like:

```
custom-options.sh
custom-options-5.sh
custom-options-5.3.sh
custom-options-5.3.1.sh
```

This structure give us very granular control over the PHP options, and this one the nicest features PHPFarm has to offer. Like wise we can do the same with the php.ini values:

```
custom-php.ini
custom-php-5.ini
custom-php-5.3.ini
custom-php-5.3.1.ini
```

An example options and ini file might look something like the following:

<script src="https://gist.github.com/amacgregor/11041627.js"></script>

<script src="https://gist.github.com/amacgregor/11041706.js"></script>

## Installing Multiple Versions of PHP

Previously, we installed one of the older versions of **PHP5.3** but in order the get the hang of working with multiple versions of php, let's go ahead and install the latest versions of **PHP5.4** and **PHP5.5**:

```
$ cd /opt/phpfarm/src/
$ ./compile.sh 5.4.27
$ ./compile.sh 5.5.11
```

In order to confirm that everything was installed correctly let's verify each of the php versions we installed works:

```
$ /opt/phpfarm/inst/php-5.3.1/bin/php -v
$ /opt/phpfarm/inst/php-5.4.27/bin/php -v
$ /opt/phpfarm/inst/php-5.5.11/bin/php -v
```

After running each one of those commands you should see each version's full information, but is highly inconvenient if we have to type the full path to each of the php versions, right ? Well no worries PHPFarm actually has our back on this one, PHPFarm comes included with a command called with _**switch-phpfarm**_.

Let's try it out:

```
$ switch-phpfarm 5.4.27
```

After running that we can go ahead and try to get php information by doing the following:

```
$ php -v
PHP 5.4.27 (cli) (built: Apr 18 2014 10:41:43) (DEBUG)
Copyright (c) 1997-2014 The PHP Group
Zend Engine v2.4.0, Copyright (c) 1998-2014 Zend Technologies

```

It's as simple as that, **switch-phpfarm** takes care of creating the necessary symlinks need to run php; switching back to **PHP5.3** is as simple as too:

```
$ switch-phpfarm 5.3.1
$ php -v
PHP 5.3.1 (cli) (built: Feb  9 2014 16:11:15) (DEBUG)
Copyright (c) 1997-2013 The PHP Group
Zend Engine v2.3.0, Copyright (c) 1998-2013 Zend Technologies

```

## Adding Apache to the Mix

So we have multiple **PHP** versions running side by side and we can execute code by calling the php version directly or by changing the current version, however this is not very useful, real world **PHP** development goes well beyond single scripts executed through the shell. We need to be able to execute and test complex applications, and for that, we need a web server.

Personally, I like to use **mod_proxy_fcgi** and **PHP-FPM** on my development and production stacks, however **mod_proxy_fcgi** is only available on Apache2.4 which unfortunately is not an option for some developers out there, but no need to worry we can still setup older versions of Apache to run specific versions of PHP per VirtualHost.

<div class="notice">
<strong>Note:</strong> I would still highly recommend using Apache2.4 and mod_proxy_fcgi, the module provides a lot of flexibility and allows you to segment parts of your applications, for example, running the backend and frontend of Magento using different PHP-FPM pools or even one running HHVM
</div>

For this article's example purposes we will use **mod_fastcgi** in order to run different version of PHP per VirtualHost. The first thing we need to do is make sure that mod_fastcgi is installed and running; in Ubuntu this can easily be done by running:

```
$ a2enmod fastcgi actions suexec
$ service apache2 restart
```

Next we need to tell **Apache** where it can find the configuration for the multiple **fastcgi** servers, open the apache configuration file located in _/etc/apache2/apache2.conf_ and add the following lines at the end of it:

```
# Include FastCGI configuration for PHPFarm
IncludeOptional cgi-servers/*.conf
```

Now we need to create the _**cgi-servers/**_ directory and the corresponding file:

```
$ sudo mkdir /etc/apache2/cgi-servers/
$ cd /etc/apache2/cgi-servers/
```

Inside create a file named _**php-cgi-5.3.28**_ and copy the following content:

```
FastCgiServer /srv/www/cgi-bin/php-cgi-5.3.28
ScriptAlias /cgi-bin-php/ /srv/www/cgi-bin/
```

Next let's create the file _**/srv/www/cgi-bin/php-cgi-5.3.28**_:

```
#!/bin/sh
PHPRC="/etc/php5/cgi/5.3.28/"
export PHPRC

PHP_FCGI_CHILDREN=3
export PHP_FCGI_CHILDREN

PHP_FCGI_MAX_REQUESTS=5000
export PHP_FCGI_MAX_REQUESTS

PHP_FCGI_IDLE_TIMEOUT=5000
export PHP_FCGI_IDLE_TIMEOUT

exec /opt/phpfarm/inst/bin/php-cgi-5.3.28
```

We also need to make sure the file is actually executable:

```
$ sudo chmod +x /srv/www/cgi-bin/php-cgi-5.3.28
```

Finally, we can go ahead and create a virtual host that points to the newly create php-cgi server:

<script src="https://gist.github.com/amacgregor/11049832.js"></script>

Let's now enable our **VirtualHost** and restart the Apache server:

```
$ a2ensite test.mydomain.com.conf
$ service apache2 restart
```

Now let's make sure our **Virtual Host** is loading the proper **PHP** correctly, to do this we can create a phpinfo script on the root directory of our VirtualHost, with the following content:

```
<?php phpinfo(); ?>
```

With this setup we can install and use as many PHP version as we want, side by side and without any conflicts.

## Final Comments

Although this setup is tailored to my work flow, I'm sure that other developers will find useful or at the very least will give you ideas to improve your own development environment and work flow.

Also if you spot any errors, have any suggestions or want to share your own setup please feel free to leave a comment on the section below.
