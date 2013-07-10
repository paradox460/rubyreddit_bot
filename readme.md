You're currenly on our prototype, evented branch. Nothing works just yet, but in the end this will be version 2.0.0 of the bot.

# Why Evented?
Going evented presents its own share of complications, but in the end can provide a faster, more preformant bot. An evented bot can respond to new posts faster, use less resources, and be daemonized, so it doesn't have to rely on cron or other schedulers.

The downside of evented programmings are still present, such as race conditions and, in our case, being throttled by reddit. However, it is possible to code provisions to deal with this

# Design Ideas

## Multiple processers
Having a pool of "processors" allows us to deal with incoming subreddit data tremendously quickly. Most servers (and home computers) are multi-core, hell, most *phones* are multi-core, so having a single linear proceedural bot makes little sense.

## Request queue
If we create a processing pool, we have to be wary of hitting the reddit API too much. reddit states that a user or bot should not make more than 30 requests per minute, which is one request every 2 seconds. In prior versions of this bot, this was handled by a `sleep 2` after every single request. While simple, this means that with every subreddit you added, even with just one rule, the total runtime of the script went up by 6 seconds (hey, it was coded over a thanksgiving break)

## Making use of new reddit features
The old bot made use of a few reddit features, such as hiding posts its seen before, and not acting on approved *things*.

We would like to do even better. By using multi-reddits, we can effectively cut down the requests made to reddit tremendously. Most users of the bot have it active on 5-10 subreddits. A single multi-reddit can return the data from at least 50 reddits, in one request. It seems almost foolish not to use them.

For comments we can keep track of the last comment fetched from a multi-reddit, and use the "after" property to reduce load on reddit servers, and eliminate redundant parsing.

## Constant polling
Since we're in an EM loop, all we have to do is register a timer that fetches our multireddit at a configurable interval. The temptation with this is to set the interval tremendously high, something like 5 seconds, so the bot is *always* pulling data. In reality, even on one of the largest subreddits, posts and comments only come in at the most frequent every 20 seconds (they may come in sooner but they don't manifest themselves on reddit), and having the bot make full requests for *one* comment is a serious misuse of resources.

## Rules syntax
I plan to keep the yaml configs almost entirely the same, but with a few additions, namely, a new "rules" syntax. Rules will be another block, where you can define custom rules, similar to the existing ones already. The advantage of rules, though, is a single rule can be easily applied to multiple subreddits. No more having to deal with YAML aliases, no more having to cut and paste the same 5 banned regexes to every subreddit.

This feature is similar to automoderator's rules, but will be designed to fit in with the precedent set by the bot, so the structure will be different.

# Implementation Details

## Request queue
Everything goes through a singular request queue, which is bound to an [eventmachine][em] repeating timer of 2 seconds. Both data fetching and bot actions will go through this queue, and neither will be given priority over the other. This prevents one hyperactive subreddit from shutting down the bots actions on other subreddits

## Incoming queue
Assuming worst case scenario, we may occasionally have data coming in faster than the bot can parse and preform mod actions. In this case, every request result will be dumped into a queue. The processors in the processor pool will pop results out of this queue, thus preventing race conditions

## Multireddits
I mentioned these above, but should write about them again. Currently, the bot runs its main loop *once* for every subreddit, after fetching all the data, and this allows it a fairly simple way of filtering by subreddit. In switching to a multireddit+queue model, we will have to change the approach to read through the rules with EVERY parsing. This incurs a slight preformance hit, but is negated by the pool count's tremendous efficiency. If better programmers than I have a solution to this, i welcome any feedback.

## EM-Synchrony
This project/rennovation will be making use of both [eventmachine][em] and [em-synchrony][em-s]. EventMachine is a standard ruby event loop. EM-Synchrony is a series of modifications to eventmachine that provide for fiber-based programming, which allows for high concurrency.

I recommend reading [this blogpost](http://www.igvita.com/2010/03/22/untangling-evented-code-with-ruby-fibers/) by the author of EM-Synchrony as to what it does and why it does it.

[em]: https://github.com/eventmachine/eventmachine
[em-s]: https://github.com/igrigorik/em-synchrony
