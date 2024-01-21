---
title: A Python-Flask Image Factory
date: 2015-10-15
description: Live image resizing web-service
---

This article is a indirect successor to [JavaScript-lazyload](/posts/lazyloading_javascript). You might want to read this first. To recap: We have designed a JavaScript routine, which will load images based on the view-ports size and position. Previously we have pre-generated those images and returned specific resolutions as static content, now we want to automatically scale images according to URL arguments.

### Flask location block
In this guide we assume a media URL will look like this:

![URL Example Colored](/image_factory_url_example.png)

First we need a flask route, note that if you are using the default static location, you cannot send files from outside the ‘static’-directory.

The `<path:path>` maps the path after *"picture"* to the `path` argument. In addition we evaluate the URL-arguments. The function `generateImage` will be explained in the next section.

    # unset default static directory if you want to
    app = flask.Flask("NAME", static_folder=None)
    @app.route("/picture/<path:path>")
    def sendImage(path):
        
        scaleY = flask.request.args.get("scaley")
        scaleX = flask.request.args.get("scalex")
        encoding = flask.request.args.get("encoding")
        
        scaleY = round(float(scaleY))
        scaleX = round(float(scaleX))
        
        pathToGeneratedImage = generateImage(path, scaleX, scaleY, encoding)
        response = flask.send_from_directory(...)
        
        return response

### Re-encoding, resizing and caching
Now we create a function, which will generate an image with the requested specifications from the original and save it to a caching path, which the function then will return.

We use the python module `pillow` (aka *PIL*) to resize and re-encode the images, specifically `PIL.Image.thumbnail`.

    CACHE_DIR = "someotherdir/"
    
    import PIL.Image
    def generateImage(pathToOrig, scaleX, scaleY, encoding):
        '''Generate image with the requested scales and encoding'''
    
        # create a cache dir if it doesn't already exist #    
        if os.path.isfile(CACHE_DIR):
            raise OSError("Picture cache dir name is occupied by a file!")
        if not os.path.isdir(CACHE_DIR):
            os.mkdir(CACHE_DIR)
    
        # use same encoding if none is given # 
        filename, extension = os.path.splitext(os.path.basename(pathToOrig))
        if not encoding:
            encoding = extension.strip(".")
    
        # fix some extensions PILLOW doesn't like #
        if encoding.lower() == "jpg":
            encoding = "jpeg"
    
        # open image #
        image = PIL.Image.open(os.path.join(PICTURES_DIR, pathToOrig))
    
        # ensure sizes are valid #
        x, y = image.size
        if not scaleY:
            scaleY = y
        scaleX = min(x, scaleX)
        scaleY = min(y, scaleY)
    
        # generate new paths #
        FILE_FORMAT = "x-{x}-y-{y}-{fname}.{ext}"
        newFile = FILE_FORMAT.format(x=scaleX, y=scaleY, fname=filename, ext=encoding)
        newPath = os.path.join(CACHE_DIR, newFile)
    
        # save image with new size and encoding #
        image.thumbnail((scaleX, scaleY), PIL.Image.ANTIALIAS)
        image.save(newPath, encoding)
    
        # return the new path # 
        return newPath

Server: generate new image
If you want to add additional headers to the response, you may add this extra step before returning the response.

    raw = flask.send_from_directory(PICTURES_DIR, pathToGeneratedImage, cache_timeout=3600)
    response = flask.make_response(raw)

And that’s it, now our picture-route supports scaling and encoding! As I said in the beginning, you might want to read [JavaScript-lazyload](/posts/lazyloading_javascript) for an idea on how to deploy this to your website.

<sup style="font-style: italic;">by Yannik Schmidt</sup><br>
<sup>**Tags:** _Web-Development, Fullstack, Python, SEO, JavaScript_</sup>
