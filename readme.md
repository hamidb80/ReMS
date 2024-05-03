> People are asleep, they wake up when they die - Muhammad the prophet (PBUH)

[![StandWithPalestine](https://raw.githubusercontent.com/Safouene1/support-palestine-banner/master/StandWithPalestine.svg)](https://github.com/Safouene1/support-palestine-banner)

# ReMS :: Remembering Management System
I know the name is wierd, I might change it.

> [!WARNING]
> the project is under active development. I will make a tutorial and demo about it when it hit version 1.0

## Demo
https://github.com/hamidb80/ReMS/assets/33871336/e0a85a69-1881-4540-8a53-f5951df85682

https://github.com/hamidb80/ReMS/assets/33871336/e1cac5a9-9b50-4b1b-ab29-f80fa302d5d0


## Inspirations
### Content
- [what good is learning if I don't remember it?](https://files.eric.ed.gov/fulltext/EJ1055665.pdf)
- active learning vs passing learning / scout young
- [spatial web browsing](https://maggieappleton.com/spatial-web)
- [libre texts](https://libretexts.org/) + [HELM :: Helping Engineers Learn Mathematics Workbooks](https://www.lboro.ac.uk/departments/mlsc/student-resources/helm-workbooks/) +  [differential equations web tutorial](https://tutorial.math.lamar.edu/classes/de/de.aspx) + [Pendulum Equations](https://www.cfm.brown.edu/people/dobrush/am34/Mathematica/ch3/pendulum.html) + [learn me a bitcoin](https://learnmeabitcoin.com/technical/transaction/input/vout/) + [A* exaplined](https://www.redblobgames.com/pathfinding/a-star/introduction.html)

### Ideas from other softwares
- Github's colorful issue tags and the ability to search by language, date, ...
- `Saved Messages` in telegram (or any other messanger)
- Pinterest style (Masonry) layout
- Google Keep

### Similar Works
- [OrgPad](https://orgpad.info/)
- [Tiddly Map](https://tiddlymap.org/)
- [Hyper Physics](http://hyperphysics.phy-astr.gsu.edu/hbase/hframe.html)
- [TheBrain: The Ultimate Digital Memory](https://www.thebrain.com/)
- [lpsa.swarthmore.edu](https://lpsa.swarthmore.edu/TM/tmExplore/index.html?LPSA#t_lpsahome)
- [CISCO Network Academy](http://cisco.num.edu.mn/CCNA_R&S1/course/module7/#7.0.1.1)
- [Hepta Base](https://heptabase.com/) + [Margin Note](https://www.marginnote.com/)

[Obsidian](https://obsidian.md/)? [Notion](https://www.notion.so/)? [LogSeq](https://github.com/logseq/logseq)? Nah, I didn't find them useful ...

## Philosophy
> Software is not just some code, software is made to meet some needs, software has history, software is the way its creators think, software is something alive -- me

### the system should
1. help you to ***remember better***
2. help you to ***connect the the things that you know***
3. help you to ***grasp the overall idea***
4. be a place to ***connect*** all the ***resources*** on the internet

### the system should not
1. ***distract you*** :: e.g. automatically load notes (like Intagram feeds). the user him/herself decides what to look for. user can still see feeds but this behaviour is must be taken by choice every time.
2. ***limit you*** to just uploaded contents, or create a monopoly like Twitter/Facebook. I like [open digital gardens](https://maggieappleton.com/garden-history).
3. need registeration for basic tasks (e.g. viewing notes and boards)

### How to get benefit from this sotfware
At first I thought that this software is replacement for tradiotional way of studying. I thought it is new generation of studying and others are now obsolete. But then I thought of great scientists/engineers in history that knew/did a lot, but have been using none of these tools.

I had hard time to figure out what is the best way that using this software can benefit. the best way is that you should read/watch/listen to a peice of knowledge and really engage yourself. then at the end of session/part/chapter, you should try to create a graph and summary of the contents that you know. otherwise it will be distracting and time consuming without much gain...

## Design Choices
> life is not inherently wrong or right, life is what you choose it to be ... -- [how to master your life](https://oliveremberton.com/2013/how-to-master-your-life/)

Every choice you make has its upsides and downsides. for example if your friends are gossiping about other one or saying dirty words, you can mention them that it is wrong, they probably get a little mad at you or chances are that they not like you as before, but at least your ego is not blaming on you [because you did what is right]. or you can gossip just like them and laugh at their dirty talks and you know, just have some fun! your ego will be neutral if you do it more and more. So, depending on your purpose [in above example, doing what is right or not being alone by having bad¹ friends] you make your choice.

¹ maybe they are not bad, but just unaware of their actions, as Jesus said: "hate the sin, love the sinner".

### Note Editor
I've seen a lot of content editors, like WYSIWYG and markdown or combination of both. I liked block based editors like Jupyter-notebook more, Notion/Obsidian/Logseq editors seemed wierd and limited. the major drawback for markdown was right-to-left languages. since my primary language is Persian and I write content for Persian readers, it is a major drawback. yes I know that I can wrap everything in `<div dir="rtl">...</div>` or I can useother markup languages, but they seem both unnecessary and bloat.

So I imagined a editor like `inspect elements` of web browsers, simply store contents in tree manner.

#### Demo
https://github.com/hamidb80/ReMS/assets/33871336/151177cb-b5f4-4324-ade0-569e61f8cd25

## Current State
I think the software now reached its minimum viable product [or MVP]. but ... 

### Things I wanna improve
- the graph viewer is slow specially on larger graphs. I think I have to use WebGL like [sigmajs](https://www.sigmajs.org/)
- the graph editor is not intuitive i.e. it has poor user experience IMHO.

### Things I wanna add
- the ability to see each note is used in which graphs.
- remembering utils (spaced repetition)

### Things I doubt about
using a SPA framework (e.g. React, Karax) is fun, you don't care much about updating your states, 
but they seems limiting when it comes to interactive components & their states in notes. they does not seem worth it. 
I wish I had more time to think about them...

## Why Nim
[Nim](https://nim-lang.org/) is simple and consice programming language [much much simpler than Python]. Nim made it a lot easier to build my app as an indie programming in less time possible. Lack of a big community didn't feel problematic.

## UI
- [SVG icons](https://www.svgrepo.com/collection/solar-bold-duotone-icons/) + [fontawesome](https://fontawesome.com/)
- [Bootstrap Litera Theme](https://bootswatch.com/litera)

## Other useful things
- [LaTex editor](https://latexeditor.lagrida.com/)
- [unicode superscript generator](https://lingojam.com/SuperscriptGenerator)
