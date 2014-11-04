Download all visible requests from an Alaveteli site

This is a work-in-progress

## Why is this necessary?

We're doing this so we can put in a submission to an Australian Senate committee that has the entire
history of correspondence on [RightToKnow](https://www.righttoknow.org.au). The committee is considering
a bill related to Freedom of Information.

## Why aren't you using the Alaveteli API?

Well we would if we could but unfortunately the api doesn't return more than a small number of the
most recent requests and so it's not possible to use the api to get the urls for all the requests.
So, instead we are to scraping the pages. I know, it's not pretty.

## Why do you need login details for the Alavateli site?

To download the zipped version of the request we need to be logged in. I think this is the case
to limit load on the server due to spiders, etc.. So we need login details so we can do this
automatically for every request.
