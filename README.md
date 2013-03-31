stainless
=========

A multi-process browser alternative to Google Chrome.

Stainless started out as a technology demo to showcase my own multi-processing architecture in response to Google Chrome (Stainless 0.1 was released three weeks after Google released Chrome for Windows). Sensing an opportunity and inspired by a growing fanbase, I decided to craft Stainless into a full-fledged browser and work on features that I hadn't seen before in other browsers.

A prime example is parallel sessions, which allow you to log into a site using different credentials in separate tabs at the same time. This new technology is woven throughout Stainless, from the private cookie storage system, to session-aware bookmarks that remember the session in which they were saved. I still believe this is a true browser innovation, and I'd love to see this implemented in Chrome.

Over the past couple of years it's been impossible for me to keep working on Stainless and as promised to many, here it is, finally available as open source and in need of serious maintenance.  My last update (on 7/25/2011) was almost two years after I had stopped active development (11/04/09), and it was pretty much a bugfix release.  As anyone could have guesses, Stainless remained popular until Google finally release Chrome Beta for the Mac.

If you are going to fork, the easy path would be to setup a development system on Snow Leopard running XCode 3.  That way you could build the current source successfully as it requires method swizzling (for multi-session cookie storage in WebKit) and private access to CoreGraphics internals (for handling cross-process window layering).  The hard path would be to replace these with modern equivalents under XCode 4 (caveat: you would lose the PowerPC compatibility, which has helped keep Stainless popular on machines that can't run Chrome).

In the end, Stainless is still a hack: multi-process by way of carefully layered multi-applications with a shared state.  And as a hack, some of its most serious issues (running in separate spaces for example) may be insurmountable.  Still, Stainless was a hack to which I devoted over a year of my life and learned a lot about tricking OS X into doing my bidding.  Hopefully it can still provide similar inspiration for other Mac developers.
