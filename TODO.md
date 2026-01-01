Tasks to do:
- [x] go over every single comment in repository and delete it if it's not absolutely necessary
- [x] modify agents and Claude.md to specify that we don't like comments anywhere unless something cannot be
      encoded by code well (if things cannot be expressed by variable and function names)
- [x] after 2 tasks above make git commit
- [x] can we show messages from agents in streaming fashion somehow? I'd like to have some more
realtime feedback, because right now there's absolutely nothing until message pops up. We don't even have
any kind of ... while agent is thinking. bad UX.
- [x] Right now when agent is thinking the 'send' button is changed into 'stop' button. They should be
2 separate buttons instead. If we send message while agent is running we just add message to the queue.
This would just extend 'Execute AI' duration, agent should then receive our message after finishing his
current work.
