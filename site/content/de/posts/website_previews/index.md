---
title: Advanced Website Previews
date: 2015-04-10
description: Advanced website previews with open graph protocol and structured data
---

This article describes how to use the *Open Graph Protocol* and *structured data (JSON-LD)* to allow messengers, other websites and search-engines to preview elements of your website.

## The Open Graph Protocol (OGP)
OGP is used for most small previews in many instant messengers like *Signal* or *Whatsapp*, but also on *Facebook* and *Twitter*. It’s relatively easy to use and the [official documentation](http://ogp.me/) actually tells you everything you need to know, but there are some potential pitfalls. Every page on your website must have a correct segment in it’s header. Here is the minimalist’s code for a basic web page:

    <html lang="en-us" prefix="og: http://ogp.me/ns#">
    <head>
        <meta property="og:type" content="website" />
        <meta property="og:title" content="Title" />
        <meta property="og:description" content="A description" />
        <meta property="og:url" content="url_of_current_page" />
        <meta property="og:image" content="http://example.de/preview_picture">
    </head>

* The prefix in the `<html ..>` definition is a [RDFa](https://rdfa.info/) extension, annotating the use of additional semantic vocabularies. Most applications will preview your web pages fine without this information. In my tests, only Telegram seems to actually require it.
* The usage of both `og:title` and `og:description seems` to be application dependent, some applications will prefer the normal meta-fields *"title"* or *"description"* if they exist. Most unfortunately, some will also show an empty description once you added a single `og:` tag but no `og:description` - even if `<meta name=description ...>` exists. Therefore I would suggest always using the same content in both `<meta type=description ..>` and the OGP-tag.
* Some applications require `og:url` to be set and will not display an image or expand the link if it isn't.
* Concerning `og:image`: While most applications will accept both a relative link (if `og:url` was provided) and an absolute link (including protocol and domain), using a fully qualified absolute link, seems to be the universally accepted format. You may define multiple pictures and resolutions here, but I found that most applications re-render the picture anyway so you will be fine with just one moderately sized picture (~1000-1600px). The extension of the picture doesn't matter and you don't have to give an image type, as long as your server sends the correct MIME-type. Some formats won't work with some applications, most notably **WebP** and **SVG** are not widely supported.
* Note that some applications and websites may impose additional restrictions or requirements, for example LinkedIn requires pictures to be at least 1200x627px. An instant messenger like Signal will display the above code structure like this:

![Instant messenger example](/web_previews/messenger_example_ogp.png)

Instead of posting your links into the application or website of your choice, you may also use [opengraphcheck.com](https://opengraphcheck.com/) to check your OGP-tags.

## Structured Data
Structured data in the form of JSON-LD is also used by some applications and websites to generate extended previews of web pages, most notably by Google for it’s [Rich Cards](https://webmasters.googleblog.com/2016/05/introducing-rich-cards.html).

Every page need’s it’s own structured data section in the HTML header, in the form of a `<script type=application/json+ld>` tag. There are different types of so called *"entities"* which represent different constructs of structured data and require different information. There are many well known types, but applications can also define/expect their own types. You can find a list of interesting entity-types in the [Google documentation](https://developers.google.com/search/docs/guides/search-gallery) or [schema.org](https://blog.atlantishq.de/post/website-previews/schema.org).

In other words, write something like this into your `<header>`:

    <script type="application/ld+json">
    {
        "@context": "http://www.schema.org",
        "@type": "Person",
        "name": "Your Name",
        "url": "https://example.com",
        "sameAs": [
                "https://github.com/FAUSheppy_",
                "https://twitter.com/its_a_sheppy",
                "https://blog.atlantishq.de/"
        ] 
    }
    </script>

The above specifically is the “social” Rich Card. You can have multiple entities after another i.e. like this:

    <script type="application/ld+json">
    {
        "@context": "http://www.schema.org",
        "@type": "Person",
        ...
    }
    </script>
    <script type="application/ld+json">
    {
        "@context": "http://www.schema.org",
        "@type": "CreativeWork",
        "author: "Your Name",
        "headline": "A title or headline",
        "description": "A description",
        "thumbnailUrl": "url_to_image",
        "image": "url_to_image"
    }
    </script>

This *"Creative Work"*-entity is documented on [schema.org](https://schema.org/CreativeWork). The parameters used in the example are the ones most often required in my experience, but, like with the OGP, applications and websites will treat these information very differently — i.e. yet again failing to default to meta-fields or straight out ignoring either *thumbnailUrl* or *image* and using one of them regardless of the size of the respectively linked image. As unfortunate as it is, I found that using the same image resolution for *thumbnailUrl* and *image* produces way more consistent results, than using a lower resolution image for *thumnailUrl*.

A testing tool for structured data can be found [here](https://search.google.com/structured-data/testing-tool).

<sup style="font-style: italic;">by Yannik Schmidt</sup><br>
<sup>**Tags:** _Structured Data, Open Graph Protocol, HTML/CSS, Web-Development, JavaScript, SEO_</sup>
