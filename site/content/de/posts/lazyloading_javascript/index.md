---
title: Lazy-loading Images in JavaScript
date: 2014-07-29
description: Lazy-loading Images in JavaScript
---

### Design Goal
We want a simple solution to lazy-loading data, based on the visible area of the website, without using any external libraries. The most obvious use case for such a system, would be the loading of images on a website, as one scrolls down the page. If you only want the code, you can find it on GitHub.

### HTML
We need an attribute or something similar which identifies the relevant elements. In this example, we will use the attribute “realsrc”, to save the URL of a image which should be lazy-loaded and displayed as a background image for the respective container. This means the HTML should look something like this:

    <img src="" realsrc="url('test.jpg')"></img>

### Event-Listener
We need event listeners, which fire upon the relevant events. If we don’t add a listener for load, lazy-loaded elements will only be loaded, once the first scroll event fires, which is generally not what we want. Likewise, if we’re using a responsive design, we need to listen for resize events, because users might expose more visible area, by resizing the window.

    window.addEventListener('scroll', refresh_handler);
    window.addEventListener('load', refresh_handler);
    window.addEventListener('resize', refresh_handler);

## Callback
We then need a callback function for the event listeners. We will call it `refresh_handler` in our example.

### Getting the relevant elements
We have given all elements, which have to change in some way, an attribute called “realsrc”. This means we now simply select all elements which have this attribute. This isn’t very efficient, however we only have to query those elements once and then cache them in a variable. We should also remember which elements were already changed. Since the DOM is parsed top down, we can increment a counter, representing the position within the array of elements until which we have already modified the respective element, so that we do not attempt to modify them again:

    # outside of callback function
    var elements = null var counter = 0
    
    # inside of callback
    elements = document.querySelectorAll("*[realsrc]");

### Getting the current view box
The most reliable, cross-browser way of calculating the current view-box, is by using an element or pseudo element on top of the page. On my web page I use my navigation bar for this, but you might as well just insert an empty container at the start of your HTML code and give it any unique ID.

    var div_at_top  = document.getElementById("navbar")
    var cur_viewbox = -div_at_top.getBoundingClientRect()

### Selecting and modifying elements
We then use a loop to iterate through the elements and modifying any contained within the view-box. We should define an offset, so that pictures are already loaded if they are almost within the visible area.

    var offset = 200
    for (var i = counter; i < elements.length; i++) {
        
        /* get position of element */ 
        var boundingClientRect = elements[i].getBoundingClientRect();
        
        /* modify element */
        if (boundingClientRect.top < window.innerHeight + offset) {
            elements[i].style.backgroundImage = newSrc;
            elements[i].removeAttribute("realsrc");
        }else{
            counter = i;
            return;
        }
        
    }

# Optional: Optimizing the execution

## Define minimum view-box change
We have already cached elements and guaranteed, that we do neither modify an element twice nor even check twice if it is within the current view-box. Scroll events, unfortunately, are triggered very rapidly. Rate limiting those is difficult, so an easier, but similarly efficient solution is to have as little code as possible executed per handler. We can achieve this by checking how much the view-box changed, at the very beginning of the handler, before doing anything else.

    /* outside of callback */
    var min_viewbox_change = 100 
    /* guarantee initial call evaluates to true */
    var viewbox_y = -Infinity
    /* inside handler/callback */
    if(cur_viewbox - viewbox_y < min_viewbox_change){
        return;
    }

## De-register Event Listener
Since we return from the handler at the first element that’s not visible within the loop, reaching the end of the loop and leaving it without a return-statement, means that there are no more elements to modify or load. This in return means that we can simply de-register the event-listeners, so they won’t be executed anymore anyway.

    window.removeEventListener('scroll', refresh_handler);

* [Complete code example](https://github.com/FAUSheppy/javascript-lazyload/blob/master/lazyload.js)

<sup style="font-style: italic;">by Yannik Schmidt</sup><br>
<sup>**Tags:** _Web-Development, SEO, JavaScript_</sup>
