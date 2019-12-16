<h1>Using Visualizations to Support Machine Learning Education for Young People Without Programming Experience</h1>
<h2>Abigail Zimmermann-Niefield</h2>
<h3>Contents</h3>
<ul>
  <li><b>UIVideo.mov</b> (An up-close video of just the UI)
  <li>A video about AlpacaML and the new additions (https://www.youtube.com/watch?v=lyDLVPfqdcM)
  <li><b>ClassificationViewController.swift</b> (Updated Swift File. Link at original repository: https://github.com/AbbieRose/AlpacaML/blob/master/LPC%20Wearable%20Toolkit/Controllers/ClassificationViewController.swift)
  <li>PDF of report
</ul>

<h4>Videos</h4>
<p>You will not be able to run the code without an iPhone, an Apple ID and a BBC Micro:Bit. If you have all these things and want to actually run the app, you can reach out to me and I can get you set up ASAP. I suspect you probably don't have all these things, so I created 2 videos to demonstrate use of AlpacaML:
  <ol>
    <li> The first video is just the UI. I trained a model of my my hand moving the micro:bit right, left, up and down. It worked pretty well, except sometimes my right and left motions were classified as both because of overcorrection movement. You can see and hear the app classify my movements, and the accompanying example. You can't actually see my movemets. </li>
    <li> To actually showcase how the app works, I took a video of me using it to identify boxing movements- Jab and Upper Cut. As you can see in the video, the motions are similar enough that the model works fine, but not great. The visualization I added adds extra information as to why this might be. It is included as a youtube link above because it was too large to put on github. </li>
  </ol>
  
  <h4>Code</h4>
  <p> The actual code to run AlpacaML is obviously much larger than just a single file. I included this file in the submission because it was the only one I changed, and you don't actually need to run my code because I included videos. The parts I changed were:
  <ol>
    <li> Added a new Chart View to the Storyboard (not included in this repository).</li>
    <li> Added and populated a dictionary to hold Colors from Charts API "Joyful" scheme so I could group examples by color for each label.</li>
    <li> In classifyChunk, call setBarChart(points) function when AlpacaML makes a classification that is not "None" </li>
    <li> Added setBarChart(data, values). Renders a bar chart that represents the inverse cost of each example. I.e. the highest bar should be the best match. </li>
    <li> Added BarChartFormatter. For some reason, the creators of Charts removed String labels in their latest version. I used this as a workaround to replace it, as described in https://stackoverflow.com/questions/39049188/how-to-add-strings-on-x-axis-in-ios-charts as I cited in the code.</li>
  </ol>
