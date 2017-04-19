﻿using UnityEngine;
using System;
using System.Collections;
using System.Linq;
using UnityEngine.UI;
using System.IO;
using System.IO.Ports;
using System.Xml;
using System.Text;
using System.Collections.Generic;
using UnityEngine.EventSystems;

public class GameControlScript : MonoBehaviour
{
    public int runDuration;
    public int numberOfRuns;
	public int numberOfAllRewards;
    public GameObject player;
    public GameObject menuPanel;
    public Image fadeToBlack;
    public Text fadeToBlackText;
    public Text rewardAmountText;
	public Text numberOfDryTreesText;
	public Text numberOfCorrectTurnsText;
	public Text numberOfTrialsText;
    public Text lastAccuracyText;
    public Text timeElapsedText;
    public UDPSend udpSender;
    public MovementRecorder movementRecorder;

	private float rawSpeedDivider;  // Normally 60f; previously 200f
	private float rawRotationDivider;  // Normally 500f; previously -4000f
    private int respawnAmplitude = 2000;
    private int runNumber;
    private float runTime;
    private long frameCounter, previousFrameCounter;
    private System.Collections.Generic.Queue<float> last5Mouse2Y, last5Mouse1Y;
    public string state;
    private bool firstFrameRun;
    private bool playerInWaterTree, playerInDryTree;
    private Loader scenarioLoader;
    private CharacterController characterController;
    private DebugControl debugControlScript;
    private bool timeoutState;

	private int smoothingWindow = 1;  // Amount to smoothen the player movement
	private bool waitedOneFrame = false;  // When mouse hits tree, need to wait a few frames before it turns black, and then pause the game

	private Vector3 startingPos;
	private Quaternion startingRot;
	private Vector3 prevPos;

	private int centralViewVisible;

    // Use this for initialization
    void Start()
    {
		Debug.Log ("started!");
        this.frameCounter = this.previousFrameCounter = 0;
        this.runNumber = 1;
		this.last5Mouse1Y = new System.Collections.Generic.Queue<float>(smoothingWindow);
		this.last5Mouse2Y = new System.Collections.Generic.Queue<float>(smoothingWindow);
        this.state = "LoadScenario";
        this.firstFrameRun = false;
        this.scenarioLoader = GameObject.FindGameObjectWithTag("generator").GetComponent<Loader>();
        this.characterController = GameObject.Find("FPSController").GetComponent<CharacterController>();
        this.debugControlScript = GameObject.Find("FPSController").GetComponent<DebugControl>();
        this.characterController.enabled = false;  // Keeps me from moving the character while typing entries into the form
        Globals.numberOfEarnedRewards = 0;
        Globals.numberOfUnearnedRewards = 0;
        Globals.rewardAmountSoFar = 0;
		Globals.numberOfDryTrees = 0;
		Globals.numberOfTrials = 1;  // Start on first trial
        this.timeoutState = false;

		this.startingPos = this.player.transform.position;
		this.startingRot = this.player.transform.rotation;

		this.prevPos = this.startingPos;

		// Will this fix the issue where rarely colliding with a wall causes mouse to fly above the wall?  No.
		this.characterController.enableOverlapRecovery = false;  

		/*
		GameObject ifld = GameObject.Find ("ScenarioInput");
		EventSystemManager.currentSystem.SetSelectedGameObject (ifld);
		Debug.Log ("focused!");
		*/

        init();
    }

    // Update is called once per frame
    void Update()
	{

		//Debug.Log ("Framerate: " + 1.0f / Time.deltaTime);
		CatchKeyStrokes ();

		// Keep mouse from scaling walls - 
		if (this.player.transform.position.y > this.startingPos.y + 0.1) {
			Vector3 tempPos = this.player.transform.position;
			tempPos.y = this.startingPos.y;
			tempPos.x = this.prevPos.x;
			tempPos.z = this.prevPos.z;
			this.player.transform.position = tempPos;
		}
		this.prevPos = this.player.transform.position;

        switch (this.state)
        {
            case "LoadScenario":
                LoadScenario();
                break;

            case "StartGame":
                StartGame();
                break;

            case "Timeout":
                Timeout();
                break;

            case "Running":
                Run();
                break;

            case "Fading":
                Fade();
                break;

			case "Paused":
				Pause ();
				break;

            case "Reset":
                ResetScenario(Color.black);
                break;

            case "Respawn":
                Respawn();
                break;

            case "GameOver":
                GameOver();
                break;

            default:
                break;
        }
    }

    public void init()
    {
        if (!Directory.Exists(PlayerPrefs.GetString("configFolder")))
            Debug.Log("No config file");

        XmlDocument xmlDoc = new XmlDocument(); // xmlDoc is the new xml document.
        xmlDoc.LoadXml(File.ReadAllText(PlayerPrefs.GetString("configFolder") + "/gameConfig.xml", ASCIIEncoding.ASCII)); // load the file.

        XmlNodeList gameConfigList = xmlDoc.SelectNodes("document/config");

        string _runDuration = "";
        string _numberOfRuns = "";
		string _numberOfAllRewards = "";
		string _rawSpeedDivider = "";
		string _rawRotationDivider = "";
        string _rewardDur = "";
        string _centralViewVisible = "";
        string _rewardSize = "";
        string _totalRewardSize = "";

        foreach (XmlNode xn in gameConfigList)
        {
			_runDuration = xn["runDuration"].InnerText;
			_numberOfRuns = xn["numberOfRuns"].InnerText;
			_numberOfAllRewards = xn["numberOfAllRewards"].InnerText;
			_rawSpeedDivider = xn["rawSpeedDivider"].InnerText;
			_rawRotationDivider = xn["rawRotationDivider"].InnerText;
			_centralViewVisible = xn ["treeVisibleOnCenterScreen"].InnerText;
            _rewardDur = xn["rewardDur"].InnerText;
            _rewardSize = xn["rewardSize"].InnerText;
            _totalRewardSize = xn["totalRewardSize"].InnerText;
        }

        int.TryParse(_runDuration, out this.runDuration);
        int.TryParse(_numberOfRuns, out this.numberOfRuns);
		int.TryParse(_numberOfAllRewards, out this.numberOfAllRewards);
		float.TryParse(_rawSpeedDivider, out this.rawSpeedDivider);
		float.TryParse(_rawRotationDivider, out this.rawRotationDivider);
		int.TryParse (_centralViewVisible, out this.centralViewVisible);
        int.TryParse(_rewardDur, out Globals.rewardDur);
        float.TryParse(_rewardSize, out Globals.rewardSize);
        float.TryParse(_totalRewardSize, out Globals.totalRewardSize);

        // Calculate tree view block value: 0 is full occlusion in the central screen = 120 degrees
        // 0.9 is full visibility with occluder pushed all the way to the screen
        Globals.centralViewVisibleShift = (float)(centralViewVisible * 0.58/120);  // 0.45/120

		//Debug.Log (Globals.centralViewVisibleShift);
        // trying to avoid first drops of water
        this.udpSender.ForceStopSolenoid();
        this.udpSender.setAmount(Globals.rewardDur);
        this.udpSender.CheckReward();
    }

    private void CatchKeyStrokes()
    {
        if (Input.GetKey(KeyCode.Escape))
            this.state = "GameOver";
        
        if (!this.state.Equals("LoadScenario") || (this.state.Equals("LoadScenario") && EventSystem.current.currentSelectedGameObject == null))
        {
            if (Input.GetKeyUp(KeyCode.U))
            {
                this.udpSender.SendWaterReward(Globals.rewardDur);
                Globals.numberOfUnearnedRewards++;
                Globals.rewardAmountSoFar += Globals.rewardSize;
                this.rewardAmountText.text = "Reward amount so far: " + Math.Round(Globals.rewardAmountSoFar);
                //this.numberOfUnearnedRewardsText.text = "Number of unearned rewards: " + Globals.numberOfUnearnedRewards.ToString();
            } else if (Input.GetKeyUp(KeyCode.T))
            {
                // Mouse is stuck so teleport to beginning
                TeleportToBeginning();
            }
        }
    }

    private void TeleportToBeginning()
    {
        this.player.transform.position = this.startingPos;
        this.player.transform.rotation = this.startingRot;
    }

    /*
     * Waits until a tree config is loaded
     * */
    private void LoadScenario()
    {
        if (this.scenarioLoader.scenarioLoaded == true)
        {
            this.menuPanel.SetActive(false);
            this.state = "StartGame";
        }
    }

    /*
     * Waits for user input to start the game
     * */
    private void StartGame()
    {
        //Debug.Log ("In StartGame()");
        this.fadeToBlack.gameObject.SetActive(true);
        this.fadeToBlack.color = Color.black;
        this.fadeToBlackText.text = "Press SPACE to start";
		//Debug.Log ("waiting for space bar");
        if (Input.GetKeyUp(KeyCode.Space))
        {
            this.runTime = Time.time;
            Globals.gameStartTime = DateTime.Now;
            Debug.Log("Game started at " + Globals.gameStartTime.ToLongTimeString());
            this.movementRecorder.SetRun(this.runNumber);
            this.movementRecorder.SetFileSet(true);
            Color t = this.fadeToBlack.color;
            t.a = 0f;
            this.fadeToBlack.color = t;
            this.fadeToBlackText.text = "";
            this.fadeToBlack.gameObject.SetActive(false);

            this.firstFrameRun = true;
            this.debugControlScript.enabled = true;
			Globals.hasNotTurned = true;
			Globals.numCorrectTurns = 0;
            this.characterController.enabled = true;  // Bring back character movement
            this.state = "Running";

            Globals.InitLogFiles();
            Globals.trialStartTime.Add(DateTime.Now.TimeOfDay);
        }
    }

    /*
     * dry trees timeout state
     * */
    private void Timeout()
    {
        this.fadeToBlack.gameObject.SetActive(true);
        this.fadeToBlack.color = Color.black;

        if (!Globals.timeoutState)
        {
            StartCoroutine(Wait());
            Globals.timeoutState = true;
        }
    }

    IEnumerator Wait()
    {
        // Maria: This is where we change seconds
        yield return new WaitForSeconds(15);

        Color t = this.fadeToBlack.color;
        t.a = 0f;
        this.fadeToBlack.color = t;
        this.fadeToBlackText.text = "";
        this.fadeToBlack.gameObject.SetActive(false);

        this.timeoutState = false;
        this.state = "Running";
    }

    /*
     * Send sync UDP.
     * Get UDP msgs and move the player
     * Send UDP msgs out with (pos, rot, inTree)
     */
    private void Run()
    {
        // send SYNC msg on first frame of every run.
        if( this.firstFrameRun )
        {
            this.udpSender.SendRunSync();
            this.firstFrameRun = false;
        }

        if( Globals.playerInDryTree && !Globals.timeoutState )
        {
            this.state = "Timeout";
        }

		//Debug.Log ("starting move");
        MovePlayer();
		//Debug.Log ("move complete");
		if (this.udpSender.CheckReward ())
			this.movementRecorder.logReward(false, true);
        //this.movementRecorder.logReward(this.udpSender.CheckReward());
        //this.movementRecorder.logReward(true);
		this.numberOfTrialsText.text = "Current trial: # " + Globals.numberOfTrials.ToString ();
        /*
        this.rewardAmountText.text = "Reward amount so far: " + Math.Round(Globals.rewardAmountSoFar).ToString();
        //this.numberOfEarnedRewardsText.text = "Number of earned rewards: " + Globals.numberOfEarnedRewards.ToString();
        //this.numberOfUnearnedRewardsText.text = "Number of unearned rewards: " + Globals.numberOfUnearnedRewards.ToString();
		this.numberOfDryTreesText.text = "Number of dry trees entered: " + Globals.numberOfDryTrees.ToString();
		if (Globals.numberOfEarnedRewards > 0) {
			this.numberOfCorrectTurnsText.text = "Correct turns: " + 
				Globals.numCorrectTurns.ToString() 
				+ " (" + 
				Mathf.Round(((float)Globals.numCorrectTurns / ((float)Globals.numberOfTrials-1)) * 100).ToString() + "%)";
            this.last21AccuracyText.text = "Last 10 accuracy: " + GetLastAccuracy(10) + "%";
		}
		//this.frameCounter++;
		//Debug.Log ("screen updated");
        */
        TimeSpan te = DateTime.Now.Subtract(Globals.gameStartTime);
        this.timeElapsedText.text = "Time elapsed: " + string.Format("{0:D3}:{1:D2}", te.Hours * 60 + te.Minutes, te.Seconds);
        if (Time.time - this.runTime >= this.runDuration)
        {
            // fadetoblack + respawn
            this.movementRecorder.SetFileSet(false);
            this.fadeToBlack.gameObject.SetActive(true);
            this.state = "Fading";
        }
    }

    public void OccludeTree(float treeLocX)
    {
        GameObject treeOccluder = GameObject.Find("TreeOccluder");
        Vector3 lp = treeOccluder.transform.localPosition;
        if (treeLocX > 20000)  // Target tree is on right side
            lp.x = -Globals.centralViewVisibleShift;
        else if (treeLocX < 20000)
            lp.x = Globals.centralViewVisibleShift;
        treeOccluder.transform.localPosition = lp;
    }

    public int GetLastAccuracy(int n)
    {
        int len = Globals.firstTurn.Count;
        int start;
        int end;
        int numTrials;
        if (len >= n)
        {
            end = len;
            start = len - n;
        }
        else
        {
            start = 0;
            end = len;
        }
        numTrials = end - start;
        int corr = 0;
        for (int i = start; i < end; i++)
        {
            if (Globals.firstTurn[i].Equals(Globals.targetLoc[i]))
                corr++;
        }
        return (int)Math.Round((float)corr / numTrials * 100);
    }

    public int GetTurnBias(int n)
    {
        GameObject[] gos = GameObject.FindGameObjectsWithTag("water");
        int len = Globals.firstTurn.Count;
        float turn0 = 0;
        int start;
        int end;
        int numTrials;
        if (len >= n)
        {
            end = len;
            start = len - n;
        }
        else
        {
            start = 0;
            end = len;
        }
        numTrials = end - start;

        for (int i = start; i < end; i++)
        {
            if (System.Convert.ToInt32(Globals.firstTurn[i]) == gos[0].transform.position.x)
                turn0++;
        }
        return (int)Math.Round((float)turn0 / numTrials * 100);
    }

    /*
     * Fade to Black
     * */
    private void Fade()
    {
        Color t = this.fadeToBlack.color;
        t.a += Time.deltaTime;
        this.fadeToBlack.color = t;

        if (this.fadeToBlack.color.a >= .95f)
        {
            this.state = "Reset";
        }
    }

	public void Pause()
	{
        this.rewardAmountText.text = "Reward amount so far: " + Math.Round(Globals.rewardAmountSoFar).ToString();
        //this.numberOfEarnedRewardsText.text = "Number of earned rewards: " + Globals.numberOfEarnedRewards.ToString();
        //this.numberOfUnearnedRewardsText.text = "Number of unearned rewards: " + Globals.numberOfUnearnedRewards.ToString();
        if (Globals.numberOfTrials > 1) {
            this.numberOfCorrectTurnsText.text = "Correct turns: " +
                Globals.numCorrectTurns.ToString()
                + " (" +
                Mathf.Round(((float)Globals.numCorrectTurns / ((float)Globals.numberOfTrials - 1)) * 100).ToString() + "%" 
                + Globals.GetTreeAccuracy() + ")";
            this.lastAccuracyText.text = "Last 20 accuracy: " + GetLastAccuracy(20) + "%";
        }

        // NB Hack to get screen to go black before pausing for trialDelay

        if (waitedOneFrame) {
			System.Threading.Thread.Sleep (Globals.trialDelay * 1000);
			waitedOneFrame = false;

            float totalEarnedRewardSize = 0;
            float totalRewardSize = 0;
            for (int i = 0; i < Globals.sizeOfRewardGiven.Count; i++) {
                totalEarnedRewardSize += (float)System.Convert.ToDouble(Globals.sizeOfRewardGiven[i]);
            }
            //			if (Globals.numberOfEarnedRewards + Globals.numberOfUnearnedRewards >= this.numberOfAllRewards)
            // End game if mouse has gotten more than 1 ml - and send me a message to retrieve the mouse?
            totalRewardSize = totalEarnedRewardSize + Globals.numberOfUnearnedRewards * Globals.rewardSize;
            Debug.Log("Total reward so far: " + totalRewardSize + "; maxReward = " + Globals.totalRewardSize);
            if (totalRewardSize >= Globals.totalRewardSize)
				this.state = "GameOver";
			else
				this.state = "Respawn";
            // Append to stats file here
            /* NB: removed as we want the mouse to run for a certain number of rewards, not trials?
			if (this.runNumber > this.numberOfRuns)
				this.state = "GameOver";
			else
				this.state = "Respawn";
				*/
        }
        else {
			waitedOneFrame = true;
		}
	}

    /*
     * Reset all trees
     * */
	public void ResetScenario(Color c)
    {
        this.runTime = Time.time;
        this.runNumber++;

        //print(System.DateTime.Now.Second + ":" + System.DateTime.Now.Millisecond);
        foreach (WaterTreeScript script in GameObject.Find("Trees").GetComponentsInChildren<WaterTreeScript>())
        {
            script.Refill();
		}
        //print(System.DateTime.Now.Second + ":" + System.DateTime.Now.Millisecond);
        this.debugControlScript.enabled = false;

		// NB edit (1 line)
		this.fadeToBlack.gameObject.SetActive(true);
		this.fadeToBlack.color = c;
		this.state = "Paused";

        // Move the player now, as the screen goes to black and the app detects collisions between the new tree and the player 
        // if the player is not moved.
        TeleportToBeginning();

        // check for game over
		/*
        if (this.runNumber > this.numberOfRuns)
            this.state = "GameOver";
        else
            this.state = "Respawn";
		*/
    }

    private void Respawn()
    {
        //Debug.Log ("Respawning");

        // NB edit - commented out to teleport mouse back to the beginning
        //int x = 20000 - Random.Range(-1 * this.respawnAmplitude, this.respawnAmplitude);
        //int z = 20000 - Random.Range(-1 * this.respawnAmplitude, this.respawnAmplitude);
        //float rot = Random.Range(0f, 360f);

        //this.player.transform.position = new Vector3(x, this.player.transform.position.y, z);
        //this.player.transform.Rotate(Vector3.up, rot);

        // NB edit - The code below comes from starting the game - ideally make a helper function?
        TeleportToBeginning();
        //this.state = "StartGame";

		// Randomly decide which of the 2 trees is visible, only if the scenario has only 2 trees.
		GameObject[] gos = GameObject.FindGameObjectsWithTag("water");

        float locx = gos[0].transform.position.x;
        float hfreq = gos[0].GetComponent<WaterTreeScript>().GetShaderHFreq();
        float vfreq = gos[0].GetComponent<WaterTreeScript>().GetShaderVFreq();

        if (Globals.gameType.Equals("detection"))
        {
            if (gos.Length == 1)
            {
                if (Globals.varyOrientation)
                {
                    float r = UnityEngine.Random.value;
                    if (r > 0.5)  // Half the time, swap the orientation of the tree
                    {
                        gos[0].GetComponent<WaterTreeScript>().SetShader(vfreq, hfreq);
                        hfreq = gos[0].GetComponent<WaterTreeScript>().GetShaderHFreq();
                        vfreq = gos[0].GetComponent<WaterTreeScript>().GetShaderVFreq();
                    }
                }

            }
            else if (gos.Length >= 2 && gos.Length <= 3)
            {
                // Redo bias correction to match Harvey et al publication, where probability continuously varies based on mouse history on last 20 trials
                // Previous attempt at streak elimination didn't really work... Saw mouse go left 100 times or so! And most mice exhibited a bias, even though they may not have before...
                int treeToActivate = 0;
                int len = Globals.firstTurn.Count;
                float r = UnityEngine.Random.value;
                float randThresh;  // varies the boundary based on history of mouse turns
                float turn0 = 0;
                int start;
                int end;
                int numTrials;
                if (len >= 21)
                {
                    end = len;
                    start = len - 21;
                }
                else
                {
                    start = 0;
                    end = len;
                }
                numTrials = end - start;
                if (gos.Length == 2)
                {
                    for (int i = start; i < end; i++)
                    {
                        if (System.Convert.ToInt32(Globals.firstTurn[i]) == gos[0].transform.position.x)
                            turn0++;
                    }
                    randThresh = 1 - turn0 / (numTrials);  // Set the threshold based on past history
                    Debug.Log("[0, " + randThresh + ", 1] - " + r);
                    treeToActivate = r < randThresh ? 0 : 1;
                }
                else if (gos.Length == 3)
                {
                    float turn1 = 0;
                    for (int i = start; i < end; i++)
                    {
                        if (System.Convert.ToInt32(Globals.firstTurn[i]) == gos[0].transform.position.x)
                            turn0++;
                        else if (System.Convert.ToInt32(Globals.firstTurn[i]) == gos[1].transform.position.x)
                            turn1++;
                    }

                    float t0 = 1 - turn0 / numTrials;
                    float t1 = 1 - turn1 / numTrials;
                    float t2 = (turn0 + turn1) / numTrials;  // simplifies to this

                    float thresh0 = t0 / (t0 + t1 + t2);
                    float thresh1 = t1 / (t0 + t1 + t2) + thresh0;

                    Debug.Log("[0, " + thresh0 + ", " + thresh1 + ", 1] - " + r);
                    treeToActivate = r < thresh0 ? 0 : r < thresh1 ? 1 : 2;
                }
                for (int i = 0; i < 2; i++)  // Even in the 3-tree case, never deactivate the 3rd tree
                {
                    gos[i].SetActive(true);
                    if (i == treeToActivate)
                    {
                        gos[i].GetComponent<WaterTreeScript>().Show();
                        //Debug.Log("Activated tree id = " + i.ToString());
                    }
                    else
                    {
                        gos[i].GetComponent<WaterTreeScript>().Hide();
                        //Debug.Log ("Inactivated tree id = " + i.ToString ());
                    }
                }
                locx = gos[treeToActivate].transform.position.x;
                hfreq = gos[treeToActivate].GetComponent<WaterTreeScript>().GetShaderHFreq();
                vfreq = gos[treeToActivate].GetComponent<WaterTreeScript>().GetShaderVFreq();
            }
        }
        else if (Globals.gameType.Equals("match") || Globals.gameType.Equals("nonmatch"))
        {
            // First, pick an orientation at random for the central tree
            float rOrient = UnityEngine.Random.value;
            float targetHFreq = gos[0].GetComponent<WaterTreeScript>().GetShaderHFreq();
            float targetVFreq = gos[0].GetComponent<WaterTreeScript>().GetShaderVFreq();
            float targetDeg = gos[0].GetComponent<WaterTreeScript>().GetShaderRotation();
            // For now, just support vertical or horizontal orientations - support twisting later

            if (rOrient < 0.5)  // Switch target to opposite of initiation
            {
                gos[0].GetComponent<WaterTreeScript>().SetShader(targetVFreq, targetHFreq, targetDeg);
            }
            // Second, randomly pick which side the matching orientation is on
            float rSide = UnityEngine.Random.value;
            targetHFreq = gos[0].GetComponent<WaterTreeScript>().GetShaderHFreq();
            targetVFreq = gos[0].GetComponent<WaterTreeScript>().GetShaderVFreq();
            if (rSide < 0.5)  // Set the left tree to match
            {
                gos[1].GetComponent<WaterTreeScript>().SetShader(targetHFreq, targetVFreq, targetDeg);
                gos[2].GetComponent<WaterTreeScript>().SetShader(targetVFreq, targetHFreq, targetDeg);
                if (Globals.gameType.Equals("match"))
                {
                    gos[1].GetComponent<WaterTreeScript>().SetCorrect(true);
                    gos[2].GetComponent<WaterTreeScript>().SetCorrect(false);
                }
                else
                {
                    gos[1].GetComponent<WaterTreeScript>().SetCorrect(false);
                    gos[2].GetComponent<WaterTreeScript>().SetCorrect(true);
                }
            }
            else // Set the right tree to match
            {
                gos[1].GetComponent<WaterTreeScript>().SetShader(targetVFreq, targetHFreq, targetDeg);
                gos[2].GetComponent<WaterTreeScript>().SetShader(targetHFreq, targetVFreq, targetDeg);
                if (Globals.gameType.Equals("match"))
                {
                    gos[1].GetComponent<WaterTreeScript>().SetCorrect(false);
                    gos[2].GetComponent<WaterTreeScript>().SetCorrect(true);
                }
                else
                {
                    gos[1].GetComponent<WaterTreeScript>().SetCorrect(true);
                    gos[2].GetComponent<WaterTreeScript>().SetCorrect(false);
                }
            }
        }

        OccludeTree(locx);

        Globals.targetLoc.Add(locx);
        Globals.targetHFreq.Add(hfreq);
        Globals.targetVFreq.Add(vfreq);

        this.runTime = Time.time;
		this.movementRecorder.SetRun(this.runNumber);
		this.movementRecorder.SetFileSet(true);
		Color t = this.fadeToBlack.color;
		t.a = 0f;
		this.fadeToBlack.color = t;
		this.fadeToBlackText.text = "";
		this.fadeToBlack.gameObject.SetActive(false);

		this.firstFrameRun = true;
		this.debugControlScript.enabled = true;

		Globals.hasNotTurned = true;

        Globals.trialStartTime.Add(DateTime.Now.TimeOfDay);
        this.state = "Running";
	}

    private void GameOver()
    {
        //Debug.Log ("In GameOver()");
        this.fadeToBlack.gameObject.SetActive(true);
        this.fadeToBlack.color = Color.black;
        this.fadeToBlackText.text = "GAME OVER MUSCULUS!";
        if (Input.GetKeyUp(KeyCode.Escape))
        {
            StartCoroutine(CheckForQ());
        }
    }

    private IEnumerator CheckForQ()
    {
        Debug.Log("Waiting for Q");
        yield return new WaitUntil(() => Input.GetKeyUp(KeyCode.Q));
        Debug.Log("quitting!");
        Globals.WriteStatsFile();
		this.udpSender.close();
        Application.Quit();
    }

    private void MovePlayer()
    {
		
		if (Globals.newData) {
			Globals.newData = false;

			// Keep a buffer of the last 5 movement deltas to smoothen some movement
			if (this.last5Mouse2Y.Count == smoothingWindow)
				this.last5Mouse2Y.Dequeue ();
			if (this.last5Mouse1Y.Count == smoothingWindow)
				this.last5Mouse1Y.Dequeue ();

            if (Globals.gameTurnControl.Equals("roll"))
                this.last5Mouse1Y.Enqueue(Globals.sphereInput.mouse1Y);  // nikhil changed to use yaw rather than roll
            else
                this.last5Mouse1Y.Enqueue (Globals.sphereInput.mouse1X);  // nikhil changed to use yaw rather than roll

			this.last5Mouse2Y.Enqueue (Globals.sphereInput.mouse2Y);
		
			// transform sphere data into unity movement
			//if (this.frameCounter - this.previousFrameCounter > 1)
			//print("lost packets: " + this.frameCounter + "/" + this.previousFrameCounter);
			this.previousFrameCounter = this.frameCounter;

			this.player.transform.Rotate(Vector3.up, Mathf.Rad2Deg * (this.last5Mouse1Y.Average()) / this.rawRotationDivider);
            
			Vector3 rel = this.player.transform.forward * (this.last5Mouse2Y.Average () / this.rawSpeedDivider);
			//this.player.transform.position = this.player.transform.position + rel;
			this.characterController.Move (rel);
			this.udpSender.SendMousePos (this.player.transform.position);
			this.udpSender.SendMouseRot (this.player.transform.rotation.eulerAngles.y);

			//Debug.Log (this.last5Mouse2Y.Average ());
			//Debug.Log (Time.time * 1000);

			// Send UDP msg out
			//this.udpSender.SendPlayerState(this.player.transform.position, this.player.transform.rotation.eulerAngles.y, Globals.playerInWaterTree, Globals.playerInDryTree);
		} else {
			//Debug.Log ("no new data");
		}
    }

    public void FlushWater()
    {
        this.udpSender.FlushWater();
    }

}