%{
title: 'Ethereum Zero to Hero: Setting a Development Environment',
category: 'Blockchain',
tags: ['blockchain','programming','ethereum'],
description: 'Setting up a basic private test network for Ethereum development'
}
---

This is the second part of our Ethereum Zero to Hero guide. If you have not read part, I highly recommend it before jumping ahead.

In this post, we are going to set up a basic private test-net environment for ethereum development and experimentation.

# Step 0: Requirements

- You are using **MacOS**
- You have a basic understanding of software development
- You know what Ethereum is and understand it is basic usage.
- You have a basic understanding of **MacOS Terminal usage**.
- You have **homebrew** installed

# Step 1: Setting Test-Net

While we are learning the in's and out's of Ethereum development, we probably don't want to test against the real production network with real ether.

There are several Ethereum tests-nets out in the wild for this purpose **Rinkeby** and **Morden** for example; however interacting with this networks still requires for us to acquire ethereum either by mining, or getting ether from other users.

While we will eventually work with the public test networks, for beginners like us that are just starting out, that is far from ideal, and it can be difficult to get significant amounts of ether.

A better option is setting up our **private testnet**, that we can bend and twist; as well it will allow us to gain a deeper understanding of the inner workings of the Ethereum network.

### Let's GETH Going

We will need to install the geth, a go CLI client that will allow us to run a full ethereum node locally.

```
brew tap ethereum/ethereum
brew install ethereum
```

We can verify that everything installed correctly by typing:

```
geth version
```

Which should give you an output similar to the following:

<script src="https://gist.github.com/amacgregor/82baa7aaeee50c1f20000474a569fc41.js"></script>

# Step 2: Genesis Block

![Genesis Block](/images/posts/ethereum_01_genesis.jpg)

To get our on private testnet started, we are going to need a Genesis Block. Every Blockchain requires a genesis block, which is essentially the configuration file for our blockchain.

> The genesis block is the start of the blockchain - the first block, block 0, and the only block that does not point to a predecessor block. The protocol ensures that no other node will agree with your version of the blockchain unless they have the same genesis block, so you can make as many private testnet blockchains as you would like!

1. Create a project directory, for example `ethereum_0hero`
2. Open your preferred editor and create a file named `HeroGenesis.json`
3. Copy the following contents and save the file:

<script src="https://gist.github.com/amacgregor/bbdb2c3032ef4c6f33dde51275e127bb.js"></script>

As you can see the file contents are in json and for the most part self-explanatory, but let's go over the each one of the parameters quickly to clarify their purpose.

- **coinbase**: The 160-bit address to which all rewards (in Ether) collected from the successful mining of this block has been transferred. This can be anything in the Genesis Block since the value is set by the setting of the miner when a new block is created.
- **timestamp**: A scalar value equal to the reasonable output of Unix time() function at this block inception. A smaller period between the last two blocks results in an increase in the difficulty level and thus additional computation required to find the next valid block.
- **difficulty**: It defines the mining Target, which can be calculated from the previous block’s difficulty level and the timestamp. The higher the difficulty, the statistically more calculations a Miner must perform to discover a valid block. This value is used to control the Block generation time of a Blockchain, keeping the Block generation frequency within a target range. On the test network, we keep this value low to avoid waiting during tests, since the discovery of a valid Block is required to execute a transaction on the Blockchain.
- **gasLimit**: A scalar value equal to the current chain-wide limit of Gas expenditure per block. High in our case to avoid being limited by this threshold during tests.

Finally, the config parameters are there to ensure that certain **protocol upgrades** are available from the get go.

For a full explanation check this answer in [stackexchange](https://ethereum.stackexchange.com/questions/2376/what-does-each-genesis-json-parameter-mean)

Next, we will need to initialize our chain by running the following command:

```
geth --datadir ./TestNetData init HeroGenesis.json
```

Setting the data directory is important since otherwise we will override the default data directory for the **real Ethereum network**.

The output should return something similar to the following:

<script src="https://gist.github.com/amacgregor/f576f82eec2185d284d74fcaf6f6d5ba.js"></script>

# Step 3: Running a Local Node

Now that we create our initial chain we can run it by executing the following command:

```
geth --datadir ./TestNetData --identity "HeroNode1"  --rpc --rpcport "8080" --rpccorsdomain "*" --port "30303" --nodiscover --rpcapi "db,eth,net,web3" --maxpeers 0 --networkid 24 console
```

This command does a few things:

1. Utilizes the **Genesis block** we previously created
1. It uses a custom data directory instead of the default
1. Sets the network id to 24 to prevent us from talking from noes from the main network
1. Disables **peer discovery**
1. Disables the network by setting up the maxpeers to 0
1. Launches the geth console so we can interact with the blockchain/node

The output should be something similar to the following:

<script src="https://gist.github.com/amacgregor/ab86c647c3084a521478bddf9bd88b58.js"></script>

At this point, you should be up and running, and in the geth console ready to do something, but what?

Well let's switch attention to the following Warning:

> WARN No etherbase set and no accounts found as default

We have node up and running, but it will not be much use without any accounts.

# Step 4: Creating an account

Since we are already in the Geth console is easier to ahead and create an account directly from there, in the terminal type the following:

```
personal.newAccount()
```

The console will ask for a passphrase **DO NOT LOSE THIS!**, and return a has like the following:

```
0xe857331e4e3354bb72b3751cce419c8444e89e17
```

And let's validate that the account exist by running:

```
> eth.getBalance("0xe857331e4e3354bb72b3751cce419c8444e89e17")
0
```

Now, let's put some ether into that account.

# Step 5: Let's Geth Mining

Quick recap:

- We have a working private network with a single node running locally
- We create a test account that on said private network
- We do not have any ether in that account, and we need to fix that

Now, while we could easily issue ether to our account using the **Genesis block**, let's have some fun and mine Ether on our private network.

Open a new terminal tab and running the following command:

```
get attach ./<DirectoryName>/geth.ipc
```

This will connect our second terminal to the existing geth instance and open the **Javascript** console. Inside the console run the following:

```
miner.setEtherbase("0xe857331e4e3354bb72b3751cce419c8444e89e17")
miner.start()
```

If we go back to our first terminal we should see the following happening:

<script src="https://gist.github.com/amacgregor/fec3abd38afba4a80d87a23d3f2b17eb.js"></script>

Let's go back to the second terminal and stop the miner and check our balance:

```
miner.stop()
eth.getBalance('0xe857331e4e3354bb72b3751cce419c8444e89e17')
75000000000000000000
```

Congratulations! We have now created our private network and mined our few amount of ether, and we have a valid network that we can use to developer our Smart Contracts and DApps.

In the next post of the series, we will start developing with Solidity and Smart Contracts.
