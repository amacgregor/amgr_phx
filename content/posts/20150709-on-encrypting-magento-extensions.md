%{
title: "On Encrypting Magento Extensions",
category: 'Programming',
tags: ['magento','programming','DRM'],
description: "Should Magento Connect Allow encrypted extensions"
}
---

> The opinions expressed here represent my own and not those of my employer.

Recently there has been much debate over if Magento Connect should allow encrypted extensions and if so in what shape and form. The following post is my honest, uncensored opinion about the whole situation, please read the whole thing you might be surprised by my conclusions.

# Its Rant time

Let me start by saying that **I absolutely detest encrypted extensions** and find IonCube encrypted code abhorrent. Let’s leave aside the philosophical argument about open source and
openness.

My reasons for hating obfuscated/encrypted code are much more practical and mundane, it all comes down to having control over the code is running on a specific project, having the flexibility to change it, trusting the code follows certain standards.

## Control

As developer any third party extension paid or not that goes into any of my projects has to go through several tools like php-metrics, php-codesniffer, php-messdetector and so on to make sure that the code meets certain standards. Code quality, stability and adherence to standards are things that I consider important and the lack off quality in Connect extensions was my main motivator to create [triplecheck.io](https://www.triplecheck.io)

Encryption puts code whatever quality it might be on a black box where we cannot check, test or fix it; worse comes to worse we are still responsible for supporting an maintaining the sites running said extension. Moreover, believe me, not every merchant is going to be understanding enough when you tell them

> “Well there is nothing I can do to fix the extension, I have to wait for the extension developer to answer back; with luck it will be in a week.
> Please close your business for the meantime.”

## Flexibility

Now don’t get me wrong there are some really good extensions in the market and some exceptional extension providers out there, but that being the case sometimes we need a to add functionality to a third party extension that get us 3/4 of the way to where we need to be.

With an encrypted codebase, that is not an option you get what you paid for and sometimes even less, as a developer I cannot debug or extend a third party extension. I am confined to a little black box of obfuscation, and complete powerless to change it.

## Security and Trust

Encrypting code even if is part of the overall extension is asking for merchants and developers to trust on that extension provider, and Big Time. There could be anything hiding inside that encrypted file.

And no, I am not playing with scare tactics here, let put a little code snippet as an
example:

```
    public function validate()
    {
        return $this;
        parent::validate();
        $currency_code = $this->getOrderData()->getBaseCurrencyCode();
        if (!in_array($currency_code,$this->_allowCurrencyCode)) {
            Mage::throwException(Mage::helper(‘extensionname’)->__(‘Selected currency
code (‘.$currency_code.’) is not compatible with extensionname’));
        }
        //mage::log(“Validate “);
        return $this;
    }
```

Yes, this charming piece of code goes for around **$300USD** the code was taken as it is but the name removed. Good luck trying to figure what was happening if the code was encrypted; extensions like this one are why encryption also becomes a trust problem; can you trust the extension developer not to take shortcuts, follow best practices and not do stupid code like the one above?

# Time for a sensible argument

By know I have established my complete dislike of encrypted code, and if that is true the only logical conclusion can be that Magento Connect should not allow encrypted extension on its market place, right?

Well no, after a lot of though and consideration, I do believe that encrypted extensions should be allowed into Connect, and you are probably thinking. **Wtf?! after that rant!? you are saying yes to encrypted code!!!**

I am and for a very simple reason, Magento Connect should be a platform open to everyone wanting to sell and promote their extensions; is up to the extension developer to decide if they want go that route, and is up to the merchant to decide if they want to deal with the possible drawbacks.

In the end, regardless my or anyone else personal preferences the market will speak. **Will encrypted extensions thrive or wither**? Is up to the ecosystem and the market to decide.
