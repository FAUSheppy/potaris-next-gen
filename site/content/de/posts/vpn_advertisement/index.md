---
title: A harsh critisism of VPN advertisement
date: 2020-09-07
description: 
---

All my tech-savvy readers and YouTube using colleagues, of course cringe, whenever they accidentally end up on a video with a VPN sponsoring. A sponsoring usually not in the form of an traditional ad, but as a spoken endorsement by the creator himself, so my god damn adblocker can’t block it.

And it’s become so many, basically all medium sized youtubers who need to make some money on the platform since the YouTube-adpocalypse, have, at some point, gone down the VPN shilling route. But this is not only a lesson about the problems of having individuals with no formal education in journalistic ethics, oversight or knowledge selling magic beans, but also on how unbelievably uneducated and sheepish the general populous must be, when it comes to technology in general and information security in particular.

So sit down boys and girls, let me be the first and hopefully the last person to explain to you, why VPNs only have very specific use cases and that you shouldn’t even have used it to illegally download Game of Thrones in 2018, let alone to protect your privacy from the government.

## What is a public hotspot/your ISP actually able see?
When VPN promoters — excuse me — VPN shills say, a VPN could protect your passwords or the data within web-forms, they are flat out lying to you. It is not the 2000s any more, HTTPS is everywhere. No, and I mean absolutely no serious websites, especially not payment providers or banks have unencrypted websites.
If your connection to a website is encrypted with HTTPS, the amount of data any attacker can see, already drops to almost zero. Leaving out some more sophisticated side-channel attacks, which a VPN won’t protect you against either, realistically, the only thing your garden-variety ISP/VPN Hotspot can see, especially without stepping into some massive legal dark-grey areas, is the IP and Server Name Identification of the server (SNI) you are connecting to. The SNI is probably the more interessting information, since most major websites have a multitude of servers serving their content and an IP address alone therefore doesn’t really tell you much.

![Server Name Identification (SNI)](/vpn_ads/server_sni.png)

Using a VPN will hide this specific information from your ISP or local WLAN hotspot, but the important problem is…

## You are only shifting trust
This is an essential problem with any VPN provider or even hosting your own VPN, just because you start using a VPN, information about your internet usage doesn’t just disappear, the only difference is: Now your VPN provider has it, instead of your ISP or local hotspot.

![Information is always somewhere](/vpn_ads/cloud_meme.png)

So the question is: Do you really trust some random, unregulated VPN provider more than your ISP? If you are living in an EU country, you are probably infinitely better off trusting your ISP and even if you live in the US or other countries, you are insanely naive if you think there won’t be logs. There are always logs, there is always an disgruntled employee somewhere, always a leak eventually, always some insecure server, switch or appliance, which got stuck on some stupid update without the monitoring catching it. You can’t trust your VPN provider, because, to put it dramatically: Information cannot be destroyed.

## What about DNS-Poisioning?
It used to be common practice of ISPs, to redirect non-existing pages (or even existing ones, though much less common), to advertising pages of the ISP itself, by manipulating DNS responses. Also some sites may be DNS blocked for legal reasons — some of them for reasons of moral ambiguity like SciHub in Germany. But again folks, it’s not 2010 any more, DNS over HTTPS is at the gate, DNS Sec adoption is gradually growing and in case of simple DNS blocking: Just use another DNS Server, than the one your ISP suggests to you. Almost any major browser or device has the option to change this. While this might be a trigger for the especially paranoid among you, just use 1.1.1.1 (cloudflare) or 8.8.8.8 (google) with HTTPS and you’re going to be fine for all intents and purposes.

![Firefox settings for safe DNS](/vpn_ads/dns_over_https.png)

A VPN won’t protect you against government surveillance, especially not from the US Government
I mean did everybody just forget Lavabit? Back in 2013, Lavabit was a security and privacy conscious mail provider, and when the NSA wanted some data about one customer and realised the only way they could do it, was by spying on all of their customers, they, of course, didn’t do it.

Oh wait, they did, they literally grabbed the company by the balls twisted them a few times, dragged them to a secret court hearing without legal representation and threatened the owner with fines of $5000 per day and jail time — funny the things you forget.

The NSA monitored the phones of European heads of state like Angela Merkel, what exactly makes you think, they couldn’t or wouldn’t listen in on some VPN provider, just because it has its seat in Geneva? Besides, it doesn’t even matter, because most government surveillance is actually done at big internet hubs. For example at the DE-CIX in Frankfurt, the German secret service literally wants to put hardware in place, to split the signals within the fibre cables itself, with one stream continuing on their way and the other one going into analysis. The DE-CIX still fights this in German courts, and while there is light on the horizon, the overall outcome remains uncertain.
The BND has officially stated, that it does share this data with its partners (e.g. the US) for non-German citizens, though many in academia have pointed out that reliably making this distinction is likely impossible.

![The ways of your HTTPS-request](/vpn_ads/flowchart.png)

## An armor won’t protect a monkey
We are all monkeys at our core. Most of the data you leak on the internet and which may potentially be used against you, doesn’t actually stem from the technical aspects of the underlying connections (when using HTTPS).

Ad Networks can track you with cookies, browser exploits don’t care if you have a VPN. VPNs can’t (thankfully) read contents of encrypted pages, meaning they can’t protect you from malicious content. If you download a cracked game and run it, there is a chance it just installs the latest ransomware and contacts its handlers right through your VPN.

There is so much more to online security than Transport Layer Security. You are much better off in terms of privacy, using Firefox with its security settings at maximum and much, much better off using Tor if you actually want to be safe from surveillance.

## Advertising Laws in Germany
Let’s come back to where we started, the massive increase in VPN advertisements on YouTube. It’s hard to imagine the usual VPN advertising on YouTube in the old media - in my country anyway, especially in the form in which it is presented on YouTube. And that is because it’s probably violating German law.

Whoever advertises in a misleading manner with the intention of creating the […] appearance of a particularly favourable […] offer through false information will be punished with imprisonment of up to two years or a fine.

> Law against malicious competition, Germany

And let’s not get started on Guidelines like [2005/29/EG](https://eur-lex.europa.eu/legal-content/DE/TXT/?uri=celex%3A32005L0029) which forbids advertisement masquerading as information. So the next time your favourite content creators says something like:

> Are you like me concerned about people doxing you and stealing your identity? Then you should use the SuperVPN-3000, it protects your online data, detects malware and stops government surveillance!

You tell him:

> You shouldn’t, it doesn’t, it can’t and it won’t. Use Tor.

I respect the desire to work on your passion and understand that everybody needs to make money somehow, but false advertising is wrong and can actually be a crime in many countries. Aside from people being juked out of their money, this kind of misinformation can do real harm, when people get lured into a false sense of online security.

<sup style="font-style: italic;">by Yannik Schmidt</sup><br>
<sup>**Tags:** _Commentary_, Privacy, Security</sup>
