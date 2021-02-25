%{
title: "First steps on HHVM",
category: 'Programming',
tags: ['hhvm','programming','php','Vagrant'],
description: "Currently a few applications are fully supported like wordpress and drupal; more complex applications like Magento are still not 100% with HHVM due to bugs in the HHVM implementation."
}
---

On a previous post [Introduction to HHVM](https://coderoncode.com/2013/07/24/introduction-hhvm.html) we went over [**HHVM**](https://www.hhvm.com/blog/)'s history and the potential of running our **PHP** applications on top of it. Currently a few applications are fully supported like wordpress and drupal; more complex applications like [**Magento**](https://www.magentocommerce.com/) are still not 100% with HHVM due to bugs in the HHVM implementation.

The first thing that we need to in order to start developing with HHVM is to setup a proper environment, for this case we are going to use a Vagrant Box.

## Skipping the Installation

If you want to skip the whole setup you can download the configured vagrant box by doing the following:

```bash
    mkdir vagrant-hhvm
    cd vagrant-hhvm
    vagrant init
    vagrant box add hhvmdev https://www.dropbox.com/s/5qyjkes49nk5abt/package.box
```


## Installing Vagrant

[Download](https://vagrantup.com/) and install the appropriate version of Vagrant for your machine.

## Downloading Ubuntu Precise (12.04)
```bash
    mkdir ~/dev/vagrant/
    cd ~/dev/vagrant/
    vagrant init
```

This will create a vagrant configuration file, this file is used for setting the configuration and provisioning our new vagrant box. We also need to download and ISO image of the **Ubuntu 12.04** vagrant can do this with a single command.

```bash
    vagrant box add base https://files.vagrantup.com/precise64.box
```

Once vagrant finishes downloading the Ubuntu image we can start our vagrant box by typing:
```bash
    vagrant up
```

Vagrant runs in headless mode (meaning there is no screen or interface, everything runs in the background) in order to be able do anything with our new box we need to open a ssh session to it. If you are working in OSX or Linux you are luck, you can login into your vagrant box by typing:

```bash
    vagrant ssh
```

Windows users can still run the command to get instructions on how to connect with vagrant by using putty or **xshell**.

Once we are logged it into our brand new vagrant box we are ready to start installing HHVM

## Installing HHVM

**Facebook** currently provides binary distributions of the HHVM, but unfortunately this binary files are nowhere near the latest updates; so in order to have the latest bug fixes and patches we have to build HHVM from the repository HEAD

### Setting up the build tools

We need to install some base tools before we can actually build HHVM:
```bash
    sudo apt-get update
    sudo apt-get install git-core cmake g++ libboost1.48-dev libmysqlclient-dev \
    libxml2-dev libmcrypt-dev libicu-dev openssl build-essential binutils-dev \
    libcap-dev libgd2-xpm-dev zlib1g-dev libtbb-dev libonig-dev libpcre3-dev \
    autoconf libtool libcurl4-openssl-dev libboost-regex1.48-dev libboost-system1.48-dev \
    libboost-program-options1.48-dev libboost-filesystem1.48-dev wget memcached \
    libreadline-dev libncurses-dev libmemcached-dev libbz2-dev \
    libc-client2007e-dev php5-mcrypt php5-imagick libgoogle-perftools-dev \
    libcloog-ppl0 libelf-dev libdwarf-dev libunwind7-dev subversion
```

### Building HHVM

Next, we need to get a copy of [HHVM GitHub repository](https://github.com/facebook/hiphop-php):

```bash
    mkdir ~/hhvm-dev/
    cd ~/hhvm-dev/
    git clone https://github.com/facebook/hiphop-php
```

Before jumping ahead and compiling HHVM we need to setup some third-party libraries required to support some of the **PHP** language features:

#### libevent

```bash
    git clone git://github.com/libevent/libevent.git
    cd libevent
    git checkout release-1.4.14b-stable
    cat ../hiphop-php/hphp/third_party/libevent-1.4.14.fb-changes.diff | patch -p1
    ./autogen.sh
    ./configure --prefix=$CMAKE_PREFIX_PATH
    sudo make && sudo make install
```

#### libCurl

```bash
    git clone git://github.com/bagder/curl.git
    cd curl
    ./buildconf
    ./configure --prefix=$CMAKE_PREFIX_PATH
    sudo make && sudo make install
```

#### Google glog

```bash
    svn checkout https://google-glog.googlecode.com/svn/trunk/ google-glog
    cd google-glog
    ./configure --prefix=$CMAKE_PREFIX_PATH
    sudo make && sudo make install
```

#### JEMalloc 3.0

```bash
    wget https://www.canonware.com/download/jemalloc/jemalloc-3.0.0.tar.bz2
    tar xjvf jemalloc-3.0.0.tar.bz2
    cd jemalloc-3.0.0
    ./configure --prefix=$CMAKE_PREFIX_PATH
    sudo make && sudo make install
```

Now we are ready for compiling HHVM:

```bash
    cd hiphop-php
    export CMAKE_PREFIX_PATH=`pwd`/..
    export HPHP_HOME=`pwd`
    cmake .
    make
```

If the compiler ran successfully and we didn't get any errors, we should be able to check HHVM version by running:

```bash
     hphp/hhvm/hhvm --version
```

Let's create a **symlink** to make our lives a little easier:

```bash
    sudo ln -s ~/hhvm-dev/hiphop-php/hphp/hhvm/hhvm /usr/bin/hhvm
```

## Next steps

Let's test **HHVM** by setting up a quick PHP script:

```bash
    mkdir -p ~/dev/scripts/
    vim ~/dev/scripts/hhvm-test.php
```

And copy the following code:

```php
    <?php echo "Hello world, I'm running HHVM\r\n"; ?>
```

Save the file, now in order to run or PHP applications through **HHVM** is important to understand how the differ from a normal **LAMP stack**(we will cover this on a later post), for now we can run our test script by running:

```bash
    hhvm ~/dev/scripts/hhvm-test.php
```

If you see the message printed on your console means that the setup was successful and we are now running HHVM.

## What's next

In the next post I'll cover the installation of Wordpress under **HHVM** and the basis for **debugging** an application running on HHVM.
