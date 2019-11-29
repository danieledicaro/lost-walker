; every time a walker stops in a safe place (so he is arrived), the variable 'finished' is increased by 1.
; when the value is equal to the number of alive walkers, the simulation ends.
globals [finished]

breed [nodes node]
breed [walkers walker]
breed [apples apple]
breed [holes hole]
breed [animals animal]

nodes-own [
  resistance ; of the terrain, by which you can discriminate between road/grass/forest
  visited ; counter from 0 to 3 that indicates how  many times a walker was on it
  attraction ; measures the force of attraction, that is proportional to its distance from the center of the attraction point
  repulsion ; measures the force of repulsion, that is proportional to its distance from the center of the repulsion point
  animal-present] ; measure the force of repulsion due to an animal present in a range of 2 nodes

walkers-own [
  location ; indicates the node where the walker is at a moment
  energy ; measures the life energy, from 0 to 100. 0 means death
  effort ; measures how much strain the walker has. He starts with 0, meaning he is ready for a long walk! Over 50 he will need to rest.
  strenght ; used during the fight with an animal. More strenght equals less decrease of energy after a battle.
  last-nodes ; it's a vector that save the last 4 positions (so you can check if the walker is stuck in a cycle)
  arrived] ; 1 means is has arrived to a safe place, so he will not move anymore. 0 otherwise

apples-own [location] ; indicates the node where the apple is
holes-own [location] ; indicates the node where the hole is
animals-own [location] ; indicates the node where the animal is at a moment

to setup
  clear-all
  set finished 0
  setup-world
  setup-apples
  setup-holes
  setup-animals
  setup-walkers
  reset-ticks
end

to go
  check-animals-on-nodes ; check the nodes with animals (because they moved last time) in order to change the values of "animal-present"
  ask walkers [
    if arrived = 0 ; if the walker is arrived (= 1), then he will not move anymore
    [
      ifelse effort < walker-effort-limit [ ; if the walker has low effort, then he will move
        ifelse pycor mod 2 = 0 ; basing on the coordinates, the calculation is slightly different (only a matter of coordinates, nothing more)
        ; evaluating all the 6 nodes around the walker
        [ set location ; where to save the new location
          min-one-of ; take the minimum "calc-next-node" among
          (nodes at-points [[0 1] [1 0] [0 -1] [-1 -1] [-1 0] [-1 1]]) ; the 6 nodes around the walker
          [ calc-next-node] ; returning the "total weigth" of each node
        ]
        ; (ELSE) the same but for different coordinates
        [ set location min-one-of (nodes at-points [[0 1] [1 1] [1 0] [1 -1] [0 -1] [-1 0]]) [ calc-next-node] ]
        face location ; look at the new location
        move-to location ; move there
        mark-as-visited ; mark the new location as visited
      ]
      ; (ELSE) the walker has a lot of effort (>= limit), then he takes a rest for this tick (he won't move), the effort will be decreased significantly and the energy slightly increased
      [ set effort ( effort - round(walker-effort-limit / 3 - 1)) ; the amout of decrease is calculated basing on the limit, so that it has sense (i.e. limit=50 -> decrease of 16)
        if use-energy [if energy < 100 [set energy (energy + 1)]]
      ]
    ]
  ]
  ask animals [
    let walker-location 0 ; if a walker is in the proximity (smell range) of the animal, in this variable will be saved its position
    ; check the presence of walkers (who is still finding a safe place) and if yes save the position of one of them
    ask [walkers in-radius animal-smell-range] of patch xcor ycor [ if arrived = 0 [set walker-location who] ]
    ifelse walker-location != 0 ; if there is a position saved, turn your attention on that walker in order to follow him
      [face walker walker-location]
      [left random 360 ] ; (ELSE) if not, turn randomly
    fd 1 ; go ahead
  ]
  ask walkers [
    if arrived = 0 [ ; if the walker is arrived (= 1), then he doesn't need to make any calculation
    if ticks mod 100 = 0 and use-effort [ set effort ( effort + 10) ] ; increase effort every 100 steps by 10
    if ticks mod 5 = 0 and use-energy [ set energy ( energy - 1) ] ; decrease energy every 5 steps by 1
    track-last-nodes ; check if finished
    check-item ; check what is on the same location
    if energy < 1 [die] ; check energy. if 0 then die
    ]
  ]
  tick
  ; if all the walkers died, then stop the simulation
  if not any? walkers [ user-message "All Walker(s) died." stop ]
  ; check the global variable to check if all the still living walkers are arrived in a safe place. If yes, stop the simulation.
  if finished = count walkers [
    user-message ( word (word count walkers " walker(s) stopped in a safe place and ") (word (walkers-number - count walkers) " died." )) stop
    ]
end

; this procedure modifies the value of "animal-present" (owned by the nodes) basing on where the animals are
to check-animals-on-nodes
  ; since the animals are moving, before setting the values they need to be reset
  ask nodes [ set animal-present 0 ]
  ; every node in the "walker-hear-range" radius from the animal will have modified the value
  ask animals [ask [nodes in-radius walker-hear-range] of patch xcor ycor [set animal-present 3] ]
end

; checking the presence of items on a location
to check-item
  ask apples at-points [[0 0]] ; if in the current location there is an apple
    [ ask walkers at-points [[0 0]] ; then ask the walker in the same location to "eat" the apple so that
      [ if use-energy [ifelse energy < (101 - apple-energy-increase) [set energy (energy + apple-energy-increase)] [set energy 100]] ; (if using energy) encrease energy by 10
        if use-effort [ifelse effort >= apple-effort-decrease [set effort (effort - apple-effort-decrease)] [set effort 0]] ; (if using effort) decrease effort by 25
    ] die ] ; after the walker ate the apple, it should not be available anymore (so the apple "dies")
  ask holes at-points [[0 0]] ; if in the current location there is a hole
    [ ask walkers at-points [[0 0]] ; then ask the walker in the same location to "come out" the hole where he fell into
      [ if use-energy [set energy (energy - hole-energy-decrease)] ; (if using energy) decrease energy by 1
        if use-effort [set effort (effort + hole-effort-increase - round(strenght / 2) )] ; (if using effort) encrease effort by 15 minus a value calcolated using the strenght of the walker
    ]]
  ask animals at-points [[0 0]] ; if in the current location there is an animal
    [ ask walkers at-points [[0 0]] ; the ask the walker in the same location to "fight" with it
      [ if use-energy [set energy (energy - animal-energy-decrease + round(strenght / 2) )] ; (if using energy) decrease energy by 10 plus a value calcolated using the strenght of the walker
        if use-effort [set effort (effort + animal-effort-increase - strenght)] ; (if using effort) encrease effort by 50 minus the strenght of the walker
    ] die ] ; after the walker fought the animal, it dies
end

; procedure for tracking the lasts 4 moves of a walker
to track-last-nodes
  ; in the vector there will be tracked only the last 4 moves
  if length last-nodes > 3 ; so if the length is > 3 (it means 4)
    [
    check-if-stuck ; go to the procedure to check if the walker is arrived
    set last-nodes [] ; reset the vector for the next 4 nodes
    ]
  ; add to the vector the current position
  let this-node 0
  ask nodes at-points [[0 0]] [ set this-node who ]
  set last-nodes lput this-node last-nodes
end

; by the vector "last-nodes" check if the walker are in a cycle (same moves)
to check-if-stuck
  let n1 item 0 last-nodes
  let n2 item 1 last-nodes
  let n3 item 2 last-nodes
  let n4 item 3 last-nodes
  if n1 = n3 and n2 = n4 [ ; if the last 4 steps are the same
    let attraction-on-node 0
    ask nodes at-points [[0 0]] [ set attraction-on-node attraction] ; save the value of attractivity of the current position
    ; if yes it means that the walker is in a safe place
    ; so set his own flag "arrived" to 1 and increment the global variable "finished" to let all know that 1 walker has stopped to walk
    if attraction-on-node != 0 [set arrived 1 set finished (finished + 1)]
  ]
end

; this procedure increments the value of "visited" owned by the nodes, so that later a walker can decide better his next move
; the range is from 0 to 4, since that value will be used to calculate the next move of the walker and higher numbers would influence negatively the choice
to mark-as-visited
  ask nodes at-points [[0 0]] [ ; ask the node in the current position
    if visited < 4 ; check if the value is already at the max value
    [set visited (visited + 1)] ; increasing it
  ]
end

; this is the procedure that calculates the "total" value of a node
; this is the smaller procedure but the heart of the simulation, since it contains the equation that determines the path of the walker
to-report calc-next-node
  let total (resistance + visited + repulsion - attraction + animal-present)
  report total
end

; catch the mouse click so that the attraction area can be created
to setup-attraction
  if mouse-down? [
    let xy []
    ; save the coordinates
    set xy lput mouse-xcor xy
    set xy lput mouse-ycor xy
    build-attraction(xy) ; call the procedure responsible for the creation
    stop
  ]
end

; catch the mouse click so that the repulsive area can be built
to setup-repulsion
  if mouse-down? [
    let xy []
    ; save the coordinates
    set xy lput mouse-xcor xy
    set xy lput mouse-ycor xy
    build-repulsion(xy) ; call the procedure responsible for the creation
    stop
  ]
end

; procedure that creates the attraction area
; it receives as parameters a vector with the coordinates of the central point
to build-attraction [ xy ]
  let value attraction-max ; this is the value of attraction in the center of the area
  ; isolate the x and y coordinates of the central point, in order to use later
  let x-attraction item 0 xy
  let y-attraction item 1 xy
  ; "radius-work" is set by the user in the "interface" tab. since it will be changed during the calculations, in the "interface" tab the user can see the value changing
  ; we need to avoid it, so we preserve the original value saving it into another value
  let radius-work attraction-radius
  ; the center of the attraction area has more "attractivity" than a point in the edge.
  ; So we need to calculate the variation of the attractivity basing on the distance from the central point.
  ; To do that, we are going to use "value-step". Starting from the border, every step we do to get closer to the central point, we will increase the "attractivity" by "value-step".
  let value-step ( value / radius-work)
  ; the initial value will be the lower one (so "value-step"), because we are going to start from the edge of the attraction area.
  set value value-step
  ; in order to display the attraction area scaling the color basing on the value of attractivity, we need to do something similar to what we did for the value
  let color-scale 4
  let color-step ( 5 / radius-work)
  ; we will assign different values to the nodes basing on their distance to the central point
  ; so we are going to select together the nodes in a precise radius, cause they have the same attractivity.
  ; we repeat this from the edge to the central point (so "radius-work" times)
  repeat radius-work [
    ask [nodes in-radius radius-work] of patch x-attraction y-attraction ; select all the nodes in a precise distance (radius-work) from the center of attraction area (x,y coordinates)
            [ set attraction value ; set the value of attractivity
              set pcolor blue + color-scale ; modify the color so that the user can have a graphic feedback of the attractivity value
             ]
    set value ( value + value-step ) ; increase the value by value-step for the next cycle (closer nodes)
    set radius-work radius-work - 1 ; decrease the radius to get closer to the center
    set color-scale round(color-scale - color-step - 0.5) ; modify the color-scale (as has been done for the value). The "-0.5" is included to make the round() function work properly.
  ]
end

; procedure that creates the repulsive area
; symmetric with the costruction of the attraction area
to build-repulsion [ xy ]
  let value repulsion-max
  let x-repulsion item 0 xy
  let y-repulsion item 1 xy
  let radius-work repulsion-radius
  let value-step ( value / radius-work)
  set value value-step
  let color-scale 4
  let color-step ( 5 / radius-work)
  repeat radius-work [
    ask [nodes in-radius radius-work] of patch x-repulsion y-repulsion [ set repulsion value set pcolor red + color-scale]
    set value ( value + value-step )
    set radius-work radius-work - 1
    set color-scale round(color-scale - color-step - 0.5)
  ]
end

; creation of the walkers and set of all the owned variables
to setup-walkers
  set-default-shape walkers "person"
  create-walkers walkers-number [
    set size 2
    set color red
    set effort 0
    set energy 100
    set strenght random 10 ; the strenght is a random value
    set last-nodes []
    set arrived 0
    set location one-of nodes ; the starting point is randomly chosen
    move-to location
    mark-as-visited
  ]
end

; creation of the apples
to setup-apples
  set-default-shape apples "apple"
  create-apples apples-number [
    set size 0.6
    set color red
    set location one-of nodes ; the location is randomly chosen
    move-to location
  ]
end

; creation of the holes
to setup-holes
  set-default-shape holes "dot"
  create-holes holes-number [
    set color black
    set location one-of nodes ; the location is randomly chosen
    move-to location
  ]
end

; creation of the animals
to setup-animals
  set-default-shape animals "wolf 4"
  create-animals animals-number [
    set size 1.5
    set color brown + 2
    set location one-of nodes ; the location is randomly chosen
    move-to location
  ]
end

; creation of the terrain
; this procedure uses a cycle in which each iteration creates one node basing on the information obtained from another procedure
to setup-world
  set-patch-size 11 ; the size of the patch
  resize-world 0 40 0 40 ; configure the size of the world and the center of the axes
  set-default-shape nodes "hex-rotated"
  ; read the information of the first node outside the cycle, because the condition will analyze the content of the node's information
  let place readLineFromFile
  while [not empty? place] [ ; continue as long as receiving information
    ; isolate the 3 information contained in the vector
    let x item 0 place ; x coordinate
    let y item 1 place ; y coordinate
    let terrain item 2 place ; the type of terrain (we are going to use this value to set the resistivity)
    create-nodes 1 [
      setxy x y
      set resistance terrain ; 1 for "road", 2 for "grass" and 4 for "forest"
      set visited 0
      set attraction 0
      set repulsion 0
      set animal-present 0
      set color scale-color green resistance 5 1 ; scale the color basing on the type of terrain, so that the user can have a graphic feedback
      set size 1.2 ]
    set place readLineFromFile ] ; obtain the information of the following node
  ask nodes [
    ; since we use the "hex" shape, in order to fill up the world properly we shift 1 rows on the left every 2 rows
    if pycor mod 2 = 0 ; every 2 rows
      [ set xcor xcor - 0.5 ] ; shift the row along the x-axis
    ; create the links between close-nodes
    ; basing on the selected row, the coordinates to select are different (only a matter of coordinates, nothing more)
    ifelse pycor mod 2 = 0
      [ create-links-with nodes-on patches at-points [[0 1] [1 0] [0 -1]] ]
      [ create-links-with nodes-on patches at-points [[1 0] [1 -1] [1 1]] ] ]
  ask links [ hide-link ] ; don't show any graphic feedback for the links
end

; this procedure reads a line of the external file containing the information of all the locations of the world and report
; after a file is opened, the pointer that let you access the data continues to go ahead every time you read a line, until you close the file
; this means that every time this procedure is called, a new line is read
; the "field-separator" refers to the separator of the information. For clarity in the examples we are going to use the character ';'
to-report readLineFromFile
  file-open file-name
  let place [] ; prepare the vector for the node's information
  ; check if not the end of file
  ifelse not file-at-end? [
    let line file-read-line ; take the entire line (consider that a line refers to the form 'x-coordinate;y-coordinate;type-of-terrain', i.e. '1;9;2')
    ; we are going to analyze each line separating the value basing on the field-separator ';'
    ; so with that character we isolate the single information
    set line word line field-separator ; due to that, we need to add ';' at the end of the line (i.e. from '1;9;2' to '1;9;2;')
    while [not empty? line] [ ; this cycle has many iterations as the number of the character ';' (so 3 iterations)
      let value-end position field-separator line ; "value-end" will contain the position of the first occourrence of the character ';'
      let value substring line 0 value-end ; we take the content of the string from the position 0 to the position took in previous line (so just the information we are interested in)
      set value read-from-string value ; the information is stored as a string, so we need to cast the data type into a number
      set place lput value place ; add the information into the vector
      ; now we need to delete the already read information
      ; to do that, we overwrite the string with the string that starts from the next position of the last read character to the end. '+1' is necessary to delete the ';'
      set line substring line (value-end + 1) length line ] ; i.e. from '1;9;2;' to '9;2;'
  ]
  [ file-close ] ; (ELSE) close the file, so that you can re-open it again from the beginning clicking the "setup" button
  report place ; return the vector with the information (if we already scanned the entire file, the vector will be empty)
end
@#$#@#$#@
GRAPHICS-WINDOW
572
16
1031
476
-1
-1
11.0
1
10
1
1
1
0
1
1
1
0
40
0
40
1
1
1
ticks
30.0

BUTTON
290
41
393
439
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
413
116
551
250
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
413
41
551
106
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
23
289
256
322
attraction-radius
attraction-radius
3
10
6.0
1
1
NIL
HORIZONTAL

SLIDER
22
370
256
403
repulsion-radius
repulsion-radius
3
10
6.0
1
1
NIL
HORIZONTAL

MONITOR
415
394
552
439
NIL
ticks
17
1
11

BUTTON
23
325
256
358
Set the center of attraction point
setup-attraction
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
22
406
256
439
Set the center of repulsion point
setup-repulsion
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
147
77
260
110
use-effort
use-effort
1
1
-1000

SWITCH
21
77
135
110
use-energy
use-energy
1
1
-1000

SLIDER
22
181
256
214
apples-number
apples-number
0
100
50.0
5
1
NIL
HORIZONTAL

MONITOR
414
264
552
309
NIL
[energy] of walkers
17
1
11

SLIDER
21
41
260
74
walkers-number
walkers-number
1
5
1.0
1
1
NIL
HORIZONTAL

SLIDER
22
217
256
250
holes-number
holes-number
0
20
10.0
1
1
NIL
HORIZONTAL

MONITOR
415
317
552
362
NIL
[effort] of walkers
17
1
11

SLIDER
21
145
256
178
animals-number
animals-number
0
10
5.0
1
1
NIL
HORIZONTAL

TEXTBOX
99
21
249
39
Walker(s) settings
11
0.0
1

TEXTBOX
54
268
276
296
Point(s) of Attraction and Repulsion
11
0.0
1

TEXTBOX
103
127
253
145
Other elements
11
0.0
1

TEXTBOX
260
459
434
487
All the information in the tab \"Info\".
11
0.0
1

TEXTBOX
36
576
268
639
The input file must contain plain text organized alike a csv file (i.e. txt, csv, rtf).\nInsert the name and indicate the field separator (i.e. , ; . :)
11
0.0
1

INPUTBOX
34
646
183
706
file-name
netlogo.csv
1
0
String

INPUTBOX
188
646
266
706
field-separator
;
1
0
String

TEXTBOX
48
550
266
568
---------------     INPUT FILE     ---------------\n
11
0.0
1

TEXTBOX
319
550
1005
569
--------------------------------------------------------------------------    PARAMETERS     --------------------------------------------------------------------------
11
0.0
1

TEXTBOX
310
576
1016
606
The following values influence either the total weight of the nodes (so the choice of the next step of the walker) or the parameters of the walkers.
11
0.0
1

INPUTBOX
326
646
407
706
attraction-max
20.0
1
0
Number

INPUTBOX
326
718
408
778
repulsion-max
10.0
1
0
Number

TEXTBOX
1071
364
1184
392
      Scroll down for\nADVANCED SETTINGS
11
0.0
1

TEXTBOX
1121
398
1136
482
|\n|\n|\n|\n|\nV
11
0.0
1

TEXTBOX
314
606
507
634
Max values of attraction and repulsion areas (set in the center of the areas).
11
0.0
1

TEXTBOX
422
670
484
688
default: 20
11
0.0
1

TEXTBOX
422
741
484
759
default: 10
11
0.0
1

INPUTBOX
547
645
675
705
animal-energy-decrease
10.0
1
0
Number

TEXTBOX
537
606
769
634
Decrease/encrease of energy/effort after meet a animal/hole/apple.
11
0.0
1

TEXTBOX
690
666
747
684
default: 10
11
0.0
1

INPUTBOX
547
973
675
1033
hole-effort-increase
15.0
1
0
Number

INPUTBOX
547
838
675
898
apple-energy-increase
10.0
1
0
Number

INPUTBOX
547
773
675
833
apple-effort-decrease
25.0
1
0
Number

INPUTBOX
547
709
675
769
animal-effort-increase
50.0
1
0
Number

INPUTBOX
547
907
675
967
hole-energy-decrease
1.0
1
0
Number

TEXTBOX
690
731
750
749
default: 50
11
0.0
1

TEXTBOX
690
794
750
812
default: 25
11
0.0
1

TEXTBOX
690
861
744
879
default: 10
11
0.0
1

TEXTBOX
690
929
742
947
default: 1
11
0.0
1

TEXTBOX
690
995
748
1013
default: 15
11
0.0
1

TEXTBOX
805
606
1015
634
The range within which the animals can smell a walker.
11
0.0
1

INPUTBOX
817
642
926
702
animal-smell-range
5.0
1
0
Number

TEXTBOX
808
722
1008
750
The range within which the walkers can hear an animal.
11
0.0
1

TEXTBOX
944
665
998
683
default: 5
11
0.0
1

INPUTBOX
816
758
927
818
walker-hear-range
2.0
1
0
Number

TEXTBOX
946
781
997
799
default: 2
11
0.0
1

TEXTBOX
808
843
1007
885
The value of effort above which the walker stops and takes a rest.
11
0.0
1

INPUTBOX
814
881
926
941
walker-effort-limit
50.0
1
0
Number

TEXTBOX
941
905
1004
923
default: 50
11
0.0
1

@#$#@#$#@
# SEMESTRAL PROJECT 2019

Student: Daniele Di Caro (p19127)
Email: p19127@student.osu.cz , danieledicaro90@gmail.com
#### Requirements
It is required that:

* in the "Turtle shape editor" are present the shapes: 'person', 'apple', 'dot', 'wolf 4' and 'hex-rotated' (means 'hex' rotated by 90 degrees)

* a plain-text file with the information of the terrain must exist:
	* default name: "netlogo.csv"
	* default location: in the same folder of this file

* The information in the file shall be arranged as follows:
	* each line refers to one node
	* each line has 3 numeric fields: x-coordinate, y-coordinate, type-of-terrain
	* each field shall be separated by a field separator (default is ';').
	* the coordinates shall be in the range 0-40

NB: at the end of this page there is a sample content.

#### How to use Attraction/Repulsion points
1. Choose all the parameters
2. Click 'Setup'
3. Click on the button 'Set attraction point" or "Set repulsion point"
4. Click with the mouse at a place in the world in order to insert that point.
5. Click 'Go' or 'Go(forever)'

## Content
Through this model it will be simulated a lost walker (or more).
When a walker goes in the central part of an attraction point, then he will stop because in a safe place.

The world is characterized by:

- 3 different types of terrain (road, grass and forest)
- attraction point
- repulsive point.

In the model are included:

- walkers
- holes
- apples
- animals.

### Walkers
A walker has energy, effort and strenght. The effort will increase every 100 ticks by 10, and the energy will decrease every 5 ticks by 1.
#### How to move
The walker will decide where to move basing on:

- the type of terrain
- on the previous path
- the attraction/repulsion points.

If a walker has a huge effort, he will rest for a tick.

If a walker is in the proximity of animals, then he will try to escape.
After a fight with an animal, both the energy and the effort will be penalized also basing on his strenght.

### Animals
If they will catch a walker, then they will die but the energy of the walker will decrease significantly and the effort will be increased.
#### How to move
An animal moves indipendently in the world, but if it smells a walker in its range, then it will follow him (except if he has found a safe place and has already stopped there).

### Holes
The holes are just obstacles in the world. If a walker falls in a hole, both his energy and effort will be penalized.

### Apples
If a walker eat an apple, then his energy will be increased and his effort decreased.

# SAMPLE CONTENT
## How-To
Due to the large number of lines, the content has been serialized as a JSON Column Array.
In order to use it, you need to re-convert it in a CSV file (i.e. http://convertcsv.com/json-to-csv.htm).

### Example
#### JSON content
{  "terrain":["1,40,4","1,39,4","1,38,2"] }
#### CSV content
1,40,4
1,39,4
1,38,2

## JSON Content
{"terrain":["1,40,4","1,39,4","1,38,2","1,37,2","1,36,2","1,35,2","1,34,2","1,33,2","1,32,2","1,31,2","1,30,2","1,29,2","1,28,2","1,27,2","1,26,2","1,25,2","1,24,2","1,23,1","1,22,1","1,21,1","1,20,1","1,19,1","1,18,2","1,17,2","1,16,2","1,15,2","1,14,2","1,13,2","1,12,2","1,11,2","1,10,2","1,9,2","1,8,2","1,7,1","1,6,4","1,5,4","1,4,2","1,3,1","1,2,1","1,1,4","1,0,4","2,40,4","2,39,4","2,38,4","2,37,4","2,36,2","2,35,2","2,34,2","2,33,2","2,32,2","2,31,2","2,30,2","2,29,2","2,28,2","2,27,2","2,26,2","2,25,2","2,24,2","2,23,1","2,22,1","2,21,1","2,20,1","2,19,1","2,18,1","2,17,1","2,16,2","2,15,2","2,14,2","2,13,2","2,12,2","2,11,2","2,10,2","2,9,2","2,8,4","2,7,4","2,6,1","2,5,1","2,4,1","2,3,4","2,2,4","2,1,2","2,0,2","3,40,4","3,39,4","3,38,4","3,37,4","3,36,4","3,35,4","3,34,2","3,33,2","3,32,2","3,31,2","3,30,2","3,29,2","3,28,2","3,27,2","3,26,2","3,25,1","3,24,1","3,23,1","3,22,1","3,21,1","3,20,4","3,19,1","3,18,1","3,17,1","3,16,1","3,15,2","3,14,2","3,13,2","3,12,2","3,11,2","3,10,4","3,9,4","3,8,2","3,7,1","3,6,1","3,5,1","3,4,4","3,3,4","3,2,4","3,1,2","3,0,2","4,40,4","4,39,4","4,38,4","4,37,4","4,36,4","4,35,4","4,34,4","4,33,4","4,32,2","4,31,2","4,30,2","4,29,2","4,28,2","4,27,2","4,26,2","4,25,1","4,24,1","4,23,1","4,22,1","4,21,1","4,20,4","4,19,4","4,18,1","4,17,4","4,16,1","4,15,1","4,14,2","4,13,2","4,12,2","4,11,4","4,10,1","4,9,1","4,8,1","4,7,1","4,6,1","4,5,4","4,4,1","4,3,1","4,2,4","4,1,2","4,0,2","5,40,4","5,39,4","5,38,4","5,37,4","5,36,4","5,35,4","5,34,4","5,33,4","5,32,2","5,31,2","5,30,2","5,29,2","5,28,2","5,27,1","5,26,1","5,25,1","5,24,1","5,23,1","5,22,1","5,21,2","5,20,1","5,19,4","5,18,1","5,17,1","5,16,1","5,15,1","5,14,1","5,13,1","5,12,2","5,11,1","5,10,4","5,9,4","5,8,1","5,7,1","5,6,1","5,5,1","5,4,1","5,3,4","5,2,2","5,1,2","5,0,2","6,40,4","6,39,4","6,38,4","6,37,4","6,36,4","6,35,4","6,34,4","6,33,4","6,32,4","6,31,4","6,30,2","6,29,4","6,28,2","6,27,1","6,26,1","6,25,2","6,24,1","6,23,1","6,22,2","6,21,2","6,20,1","6,19,1","6,18,1","6,17,1","6,16,1","6,15,1","6,14,1","6,13,1","6,12,1","6,11,1","6,10,1","6,9,1","6,8,1","6,7,1","6,6,1","6,5,4","6,4,4","6,3,2","6,2,2","6,1,2","6,0,2","7,40,4","7,39,4","7,38,4","7,37,4","7,36,4","7,35,4","7,34,4","7,33,4","7,32,4","7,31,4","7,30,4","7,29,1","7,28,1","7,27,4","7,26,4","7,25,2","7,24,1","7,23,1","7,22,2","7,21,2","7,20,1","7,19,1","7,18,1","7,17,1","7,16,1","7,15,1","7,14,4","7,13,4","7,12,1","7,11,1","7,10,1","7,9,1","7,8,1","7,7,1","7,6,4","7,5,1","7,4,1","7,3,1","7,2,2","7,1,4","7,0,2","8,40,4","8,39,4","8,38,4","8,37,4","8,36,4","8,35,4","8,34,4","8,33,4","8,32,4","8,31,4","8,30,1","8,29,1","8,28,1","8,27,4","8,26,4","8,25,4","8,24,2","8,23,4","8,22,2","8,21,4","8,20,4","8,19,1","8,18,1","8,17,1","8,16,1","8,15,1","8,14,1","8,13,1","8,12,4","8,11,1","8,10,1","8,9,1","8,8,1","8,7,1","8,6,4","8,5,1","8,4,1","8,3,1","8,2,1","8,1,4","8,0,4","9,40,4","9,39,4","9,38,4","9,37,4","9,36,4","9,35,4","9,34,4","9,33,4","9,32,4","9,31,1","9,30,1","9,29,4","9,28,4","9,27,4","9,26,4","9,25,4","9,24,4","9,23,4","9,22,4","9,21,4","9,20,4","9,19,4","9,18,4","9,17,4","9,16,1","9,15,1","9,14,4","9,13,4","9,12,1","9,11,1","9,10,1","9,9,4","9,8,1","9,7,4","9,6,1","9,5,1","9,4,1","9,3,1","9,2,1","9,1,1","9,0,4","10,40,4","10,39,4","10,38,4","10,37,4","10,36,4","10,35,4","10,34,4","10,33,4","10,32,1","10,31,1","10,30,4","10,29,4","10,28,4","10,27,4","10,26,4","10,25,4","10,24,4","10,23,4","10,22,4","10,21,4","10,20,4","10,19,4","10,18,4","10,17,4","10,16,1","10,15,1","10,14,1","10,13,1","10,12,1","10,11,1","10,10,1","10,9,4","10,8,4","10,7,4","10,6,4","10,5,1","10,4,1","10,3,2","10,2,2","10,1,1","10,0,1","11,40,4","11,39,4","11,38,4","11,37,4","11,36,4","11,35,4","11,34,4","11,33,1","11,32,1","11,31,4","11,30,4","11,29,4","11,28,4","11,27,4","11,26,4","11,25,4","11,24,4","11,23,4","11,22,4","11,21,4","11,20,4","11,19,4","11,18,4","11,17,4","11,16,4","11,15,1","11,14,1","11,13,2","11,12,4","11,11,1","11,10,1","11,9,4","11,8,4","11,7,1","11,6,1","11,5,2","11,4,2","11,3,2","11,2,2","11,1,1","11,0,1","12,40,4","12,39,4","12,38,4","12,37,4","12,36,4","12,35,4","12,34,1","12,33,1","12,32,4","12,31,4","12,30,4","12,29,4","12,28,4","12,27,4","12,26,4","12,25,4","12,24,4","12,23,4","12,22,4","12,21,4","12,20,4","12,19,4","12,18,4","12,17,1","12,16,4","12,15,1","12,14,1","12,13,4","12,12,4","12,11,1","12,10,4","12,9,4","12,8,1","12,7,1","12,6,2","12,5,2","12,4,2","12,3,2","12,2,2","12,1,1","12,0,1","13,40,4","13,39,4","13,38,4","13,37,4","13,36,4","13,35,1","13,34,1","13,33,4","13,32,4","13,31,4","13,30,4","13,29,4","13,28,4","13,27,4","13,26,4","13,25,4","13,24,4","13,23,4","13,22,4","13,21,4","13,20,4","13,19,1","13,18,1","13,17,1","13,16,1","13,15,1","13,14,1","13,13,4","13,12,1","13,11,4","13,10,4","13,9,1","13,8,1","13,7,1","13,6,1","13,5,2","13,4,2","13,3,4","13,2,4","13,1,1","13,0,1","14,40,4","14,39,4","14,38,4","14,37,4","14,36,1","14,35,1","14,34,4","14,33,4","14,32,4","14,31,4","14,30,4","14,29,4","14,28,4","14,27,4","14,26,4","14,25,4","14,24,4","14,23,1","14,22,1","14,21,1","14,20,1","14,19,4","14,18,1","14,17,4","14,16,4","14,15,1","14,14,4","14,13,4","14,12,1","14,11,4","14,10,4","14,9,1","14,8,1","14,7,2","14,6,2","14,5,1","14,4,1","14,3,1","14,2,1","14,1,1","14,0,4","15,40,4","15,39,4","15,38,4","15,37,1","15,36,1","15,35,4","15,34,4","15,33,4","15,32,4","15,31,4","15,30,4","15,29,4","15,28,4","15,27,1","15,26,1","15,25,1","15,24,1","15,23,4","15,22,1","15,21,4","15,20,4","15,19,4","15,18,4","15,17,4","15,16,1","15,15,1","15,14,4","15,13,4","15,12,1","15,11,4","15,10,4","15,9,1","15,8,4","15,7,2","15,6,2","15,5,1","15,4,2","15,3,4","15,2,1","15,1,1","15,0,1","16,40,4","16,39,4","16,38,1","16,37,1","16,36,4","16,35,4","16,34,4","16,33,4","16,32,4","16,31,1","16,30,4","16,29,1","16,28,1","16,27,4","16,26,1","16,25,4","16,24,4","16,23,4","16,22,4","16,21,4","16,20,4","16,19,4","16,18,4","16,17,4","16,16,1","16,15,4","16,14,4","16,13,1","16,12,1","16,11,4","16,10,4","16,9,1","16,8,2","16,7,2","16,6,2","16,5,4","16,4,4","16,3,4","16,2,1","16,1,4","16,0,1","17,40,4","17,39,1","17,38,1","17,37,4","17,36,4","17,35,4","17,34,1","17,33,1","17,32,1","17,31,4","17,30,1","17,29,1","17,28,1","17,27,1","17,26,4","17,25,4","17,24,4","17,23,4","17,22,4","17,21,4","17,20,4","17,19,4","17,18,4","17,17,4","17,16,1","17,15,4","17,14,4","17,13,1","17,12,1","17,11,4","17,10,4","17,9,1","17,8,2","17,7,2","17,6,4","17,5,4","17,4,4","17,3,1","17,2,1","17,1,1","17,0,1","18,40,4","18,39,1","18,38,4","18,37,4","18,36,4","18,35,1","18,34,1","18,33,4","18,32,4","18,31,4","18,30,4","18,29,1","18,28,4","18,27,4","18,26,1","18,25,1","18,24,4","18,23,4","18,22,4","18,21,4","18,20,4","18,19,4","18,18,4","18,17,1","18,16,1","18,15,4","18,14,4","18,13,1","18,12,4","18,11,4","18,10,4","18,9,1","18,8,2","18,7,2","18,6,4","18,5,4","18,4,4","18,3,1","18,2,1","18,1,1","18,0,4","19,40,1","19,39,4","19,38,4","19,37,4","19,36,4","19,35,1","19,34,4","19,33,4","19,32,4","19,31,4","19,30,1","19,29,1","19,28,4","19,27,4","19,26,4","19,25,1","19,24,1","19,23,4","19,22,4","19,21,4","19,20,4","19,19,4","19,18,4","19,17,1","19,16,1","19,15,4","19,14,4","19,13,1","19,12,4","19,11,4","19,10,4","19,9,1","19,8,4","19,7,2","19,6,4","19,5,4","19,4,4","19,3,1","19,2,1","19,1,4","19,0,4","20,40,1","20,39,4","20,38,4","20,37,4","20,36,1","20,35,4","20,34,4","20,33,4","20,32,4","20,31,4","20,30,1","20,29,4","20,28,4","20,27,4","20,26,4","20,25,4","20,24,1","20,23,1","20,22,4","20,21,4","20,20,4","20,19,4","20,18,4","20,17,1","20,16,4","20,15,4","20,14,4","20,13,1","20,12,1","20,11,4","20,10,4","20,9,4","20,8,4","20,7,4","20,6,2","20,5,2","20,4,1","20,3,4","20,2,4","20,1,4","20,0,4","21,40,4","21,39,4","21,38,4","21,37,1","21,36,1","21,35,4","21,34,4","21,33,4","21,32,4","21,31,4","21,30,1","21,29,4","21,28,4","21,27,4","21,26,4","21,25,4","21,24,4","21,23,4","21,22,1","21,21,1","21,20,4","21,19,4","21,18,4","21,17,1","21,16,4","21,15,4","21,14,4","21,13,4","21,12,1","21,11,4","21,10,4","21,9,4","21,8,4","21,7,4","21,6,2","21,5,1","21,4,1","21,3,2","21,2,2","21,1,2","21,0,4","22,40,4","22,39,4","22,38,4","22,37,1","22,36,4","22,35,4","22,34,4","22,33,4","22,32,1","22,31,1","22,30,1","22,29,4","22,28,4","22,27,4","22,26,4","22,25,4","22,24,4","22,23,4","22,22,4","22,21,1","22,20,4","22,19,4","22,18,1","22,17,1","22,16,4","22,15,4","22,14,4","22,13,4","22,12,1","22,11,4","22,10,4","22,9,4","22,8,4","22,7,4","22,6,2","22,5,2","22,4,2","22,3,2","22,2,2","22,1,2","22,0,4","23,40,4","23,39,1","23,38,1","23,37,4","23,36,4","23,35,4","23,34,4","23,33,1","23,32,1","23,31,4","23,30,1","23,29,1","23,28,4","23,27,4","23,26,4","23,25,4","23,24,4","23,23,4","23,22,4","23,21,4","23,20,1","23,19,1","23,18,1","23,17,4","23,16,4","23,15,4","23,14,4","23,13,4","23,12,1","23,11,1","23,10,4","23,9,4","23,8,4","23,7,4","23,6,2","23,5,2","23,4,2","23,3,2","23,2,2","23,1,2","23,0,2","24,40,1","24,39,4","24,38,4","24,37,4","24,36,4","24,35,4","24,34,1","24,33,1","24,32,4","24,31,4","24,30,1","24,29,4","24,28,1","24,27,1","24,26,4","24,25,4","24,24,4","24,23,4","24,22,4","24,21,4","24,20,4","24,19,4","24,18,1","24,17,4","24,16,4","24,15,4","24,14,4","24,13,4","24,12,4","24,11,1","24,10,4","24,9,4","24,8,4","24,7,4","24,6,2","24,5,2","24,4,2","24,3,2","24,2,2","24,1,2","24,0,2","25,40,1","25,39,4","25,38,4","25,37,4","25,36,4","25,35,1","25,34,1","25,33,1","25,32,4","25,31,1","25,30,4","25,29,4","25,28,4","25,27,4","25,26,1","25,25,4","25,24,4","25,23,1","25,22,1","25,21,1","25,20,1","25,19,1","25,18,1","25,17,1","25,16,1","25,15,1","25,14,4","25,13,1","25,12,1","25,11,1","25,10,4","25,9,4","25,8,4","25,7,4","25,6,2","25,5,2","25,4,2","25,3,2","25,2,2","25,1,2","25,0,2","26,40,1","26,39,4","26,38,4","26,37,1","26,36,1","26,35,1","26,34,1","26,33,4","26,32,1","26,31,4","26,30,1","26,29,1","26,28,4","26,27,4","26,26,1","26,25,4","26,24,4","26,23,1","26,22,4","26,21,4","26,20,4","26,19,1","26,18,1","26,17,1","26,16,4","26,15,4","26,14,1","26,13,1","26,12,1","26,11,1","26,10,1","26,9,4","26,8,4","26,7,2","26,6,2","26,5,2","26,4,2","26,3,2","26,2,2","26,1,2","26,0,2","27,40,4","27,39,4","27,38,1","27,37,1","27,36,1","27,35,4","27,34,4","27,33,4","27,32,4","27,31,4","27,30,4","27,29,4","27,28,1","27,27,1","27,26,1","27,25,4","27,24,4","27,23,4","27,22,4","27,21,4","27,20,4","27,19,1","27,18,4","27,17,1","27,16,4","27,15,4","27,14,4","27,13,4","27,12,4","27,11,4","27,10,1","27,9,4","27,8,4","27,7,2","27,6,2","27,5,2","27,4,2","27,3,2","27,2,2","27,1,2","27,0,2","28,40,4","28,39,1","28,38,1","28,37,1","28,36,4","28,35,4","28,34,4","28,33,4","28,32,4","28,31,4","28,30,4","28,29,4","28,28,1","28,27,1","28,26,4","28,25,4","28,24,4","28,23,4","28,22,4","28,21,4","28,20,4","28,19,1","28,18,1","28,17,1","28,16,1","28,15,1","28,14,4","28,13,4","28,12,4","28,11,1","28,10,1","28,9,4","28,8,4","28,7,4","28,6,2","28,5,2","28,4,2","28,3,2","28,2,2","28,1,2","28,0,2","29,40,1","29,39,1","29,38,1","29,37,4","29,36,4","29,35,4","29,34,4","29,33,4","29,32,4","29,31,4","29,30,4","29,29,1","29,28,1","29,27,4","29,26,4","29,25,4","29,24,4","29,23,4","29,22,4","29,21,4","29,20,1","29,19,1","29,18,4","29,17,1","29,16,1","29,15,1","29,14,1","29,13,1","29,12,4","29,11,1","29,10,1","29,9,4","29,8,4","29,7,4","29,6,4","29,5,2","29,4,2","29,3,2","29,2,2","29,1,2","29,0,2","30,40,1","30,39,1","30,38,1","30,37,4","30,36,4","30,35,4","30,34,4","30,33,4","30,32,4","30,31,4","30,30,4","30,29,1","30,28,4","30,27,4","30,26,4","30,25,4","30,24,4","30,23,4","30,22,4","30,21,4","30,20,1","30,19,1","30,18,4","30,17,1","30,16,4","30,15,4","30,14,4","30,13,4","30,12,1","30,11,4","30,10,4","30,9,4","30,8,4","30,7,4","30,6,4","30,5,2","30,4,2","30,3,2","30,2,2","30,1,2","30,0,2","31,40,4","31,39,1","31,38,1","31,37,4","31,36,4","31,35,4","31,34,4","31,33,4","31,32,4","31,31,1","31,30,1","31,29,1","31,28,4","31,27,4","31,26,4","31,25,4","31,24,4","31,23,4","31,22,4","31,21,4","31,20,1","31,19,1","31,18,4","31,17,1","31,16,1","31,15,4","31,14,4","31,13,4","31,12,4","31,11,4","31,10,4","31,9,4","31,8,4","31,7,4","31,6,4","31,5,2","31,4,2","31,3,2","31,2,2","31,1,1","31,0,1","32,40,4","32,39,1","32,38,4","32,37,4","32,36,4","32,35,4","32,34,4","32,33,4","32,32,4","32,31,1","32,30,1","32,29,1","32,28,1","32,27,1","32,26,4","32,25,4","32,24,4","32,23,4","32,22,4","32,21,1","32,20,1","32,19,1","32,18,4","32,17,4","32,16,1","32,15,4","32,14,4","32,13,4","32,12,4","32,11,4","32,10,4","32,9,4","32,8,4","32,7,4","32,6,4","32,5,4","32,4,2","32,3,2","32,2,2","32,1,1","32,0,1","33,40,4","33,39,1","33,38,4","33,37,4","33,36,4","33,35,4","33,34,4","33,33,4","33,32,4","33,31,4","33,30,4","33,29,4","33,28,4","33,27,4","33,26,1","33,25,4","33,24,4","33,23,4","33,22,4","33,21,1","33,20,1","33,19,1","33,18,4","33,17,4","33,16,1","33,15,1","33,14,4","33,13,4","33,12,4","33,11,4","33,10,4","33,9,4","33,8,4","33,7,4","33,6,4","33,5,4","33,4,4","33,3,4","33,2,1","33,1,4","33,0,4","34,40,1","34,39,4","34,38,4","34,37,4","34,36,4","34,35,4","34,34,4","34,33,4","34,32,4","34,31,4","34,30,4","34,29,4","34,28,4","34,27,4","34,26,1","34,25,1","34,24,4","34,23,1","34,22,1","34,21,1","34,20,1","34,19,4","34,18,4","34,17,4","34,16,1","34,15,1","34,14,4","34,13,4","34,12,4","34,11,4","34,10,4","34,9,4","34,8,4","34,7,4","34,6,4","34,5,4","34,4,4","34,3,1","34,2,1","34,1,4","34,0,4","35,40,1","35,39,4","35,38,4","35,37,4","35,36,4","35,35,4","35,34,4","35,33,4","35,32,4","35,31,4","35,30,4","35,29,4","35,28,4","35,27,4","35,26,4","35,25,1","35,24,4","35,23,1","35,22,4","35,21,1","35,20,1","35,19,4","35,18,4","35,17,4","35,16,4","35,15,1","35,14,4","35,13,4","35,12,4","35,11,4","35,10,4","35,9,4","35,8,4","35,7,4","35,6,4","35,5,1","35,4,1","35,3,1","35,2,4","35,1,4","35,0,4","36,40,1","36,39,4","36,38,4","36,37,1","36,36,4","36,35,4","36,34,4","36,33,4","36,32,4","36,31,4","36,30,4","36,29,4","36,28,4","36,27,4","36,26,4","36,25,1","36,24,1","36,23,4","36,22,4","36,21,1","36,20,4","36,19,4","36,18,4","36,17,4","36,16,4","36,15,4","36,14,1","36,13,1","36,12,4","36,11,4","36,10,4","36,9,4","36,8,4","36,7,4","36,6,4","36,5,1","36,4,1","36,3,4","36,2,4","36,1,4","36,0,4","37,40,1","37,39,1","37,38,1","37,37,1","37,36,1","37,35,1","37,34,4","37,33,4","37,32,4","37,31,4","37,30,4","37,29,4","37,28,4","37,27,4","37,26,4","37,25,1","37,24,4","37,23,4","37,22,1","37,21,4","37,20,4","37,19,4","37,18,4","37,17,4","37,16,4","37,15,4","37,14,4","37,13,1","37,12,4","37,11,4","37,10,4","37,9,4","37,8,4","37,7,4","37,6,1","37,5,1","37,4,1","37,3,4","37,2,4","37,1,4","37,0,4","38,40,1","38,39,1","38,38,4","38,37,4","38,36,1","38,35,1","38,34,4","38,33,4","38,32,4","38,31,4","38,30,4","38,29,4","38,28,4","38,27,1","38,26,1","38,25,4","38,24,4","38,23,4","38,22,1","38,21,4","38,20,4","38,19,4","38,18,4","38,17,4","38,16,4","38,15,4","38,14,1","38,13,1","38,12,4","38,11,4","38,10,4","38,9,4","38,8,4","38,7,1","38,6,1","38,5,1","38,4,4","38,3,4","38,2,4","38,1,4","38,0,4","39,40,1","39,39,1","39,38,4","39,37,4","39,36,4","39,35,4","39,34,1","39,33,1","39,32,4","39,31,4","39,30,4","39,29,4","39,28,4","39,27,1","39,26,4","39,25,4","39,24,4","39,23,1","39,22,1","39,21,4","39,20,4","39,19,4","39,18,4","39,17,4","39,16,4","39,15,1","39,14,1","39,13,4","39,12,4","39,11,4","39,10,4","39,9,4","39,8,4","39,7,1","39,6,1","39,5,4","39,4,4","39,3,4","39,2,4","39,1,4","39,0,4","40,40,1","40,39,4","40,38,4","40,37,4","40,36,4","40,35,4","40,34,4","40,33,4","40,32,1","40,31,1","40,30,4","40,29,1","40,28,1","40,27,4","40,26,1","40,25,1","40,24,4","40,23,1","40,22,1","40,21,4","40,20,4","40,19,4","40,18,4","40,17,4","40,16,4","40,15,4","40,14,4","40,13,4","40,12,4","40,11,4","40,10,4","40,9,4","40,8,1","40,7,1","40,6,1","40,5,4","40,4,4","40,3,4","40,2,4","40,1,4","40,0,4","41,40,1","41,39,4","41,38,4","41,37,4","41,36,4","41,35,4","41,34,4","41,33,4","41,32,4","41,31,4","41,30,1","41,29,1","41,28,4","41,27,4","41,26,4","41,25,4","41,24,1","41,23,1","41,22,4","41,21,4","41,20,4","41,19,4","41,18,4","41,17,4","41,16,4","41,15,4","41,14,4","41,13,4","41,12,4","41,11,4","41,10,4","41,9,1","41,8,1","41,7,4","41,6,4","41,5,4","41,4,4","41,3,4","41,2,4","41,1,4","41,0,4"]}
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

apple
false
0
Polygon -7500403 true true 33 58 0 150 30 240 105 285 135 285 150 270 165 285 195 285 255 255 300 150 268 62 226 43 194 36 148 32 105 35
Line -16777216 false 106 55 151 62
Line -16777216 false 157 62 209 57
Polygon -6459832 true false 152 62 158 62 160 46 156 30 147 18 132 26 142 35 148 46
Polygon -16777216 false false 132 25 144 38 147 48 151 62 158 63 159 47 155 30 147 18

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

hex
false
0
Polygon -7500403 true true 0 150 75 30 225 30 300 150 225 270 75 270

hex-rotated
false
0
Polygon -7500403 true true 150 300 30 225 30 75 150 0 270 75 270 225

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf 4
false
0
Polygon -7500403 true true 105 75 105 45 45 0 30 45 45 60 60 90
Polygon -7500403 true true 45 165 30 135 45 120 15 105 60 75 105 60 180 60 240 75 285 105 255 120 270 135 255 165 270 180 255 195 255 210 240 195 195 225 210 255 180 300 120 300 90 255 105 225 60 195 45 210 45 195 30 180
Polygon -16777216 true false 120 300 135 285 120 270 120 255 180 255 180 270 165 285 180 300
Polygon -16777216 true false 240 135 180 165 180 135
Polygon -16777216 true false 60 135 120 165 120 135
Polygon -7500403 true true 195 75 195 45 255 0 270 45 255 60 240 90
Polygon -16777216 true false 225 75 210 60 210 45 255 15 255 45 225 60
Polygon -16777216 true false 75 75 90 60 90 45 45 15 45 45 75 60

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
