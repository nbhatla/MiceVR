﻿using UnityEngine;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Xml;
using UnityEngine.UI;

public class Loader : MonoBehaviour {

    public GameObject waterTreePrefab, dryTreePrefab, wallPrefab;
    public GameObject treeParent, wallParent;
    public Text errorText;
    public MovementRecorder movementRecorderScript;
    public float dragSpeed = 10f, scrollSpeed = 20f;

    private int waterTrees, dryTrees;
    private float waterMu, waterSigma, waterMinRotationGaussian, waterMaxRotationGaussian;
    private float dryMu, drySigma, dryMinRotationGaussian, dryMaxRotationGaussian;
    private float waterMinRotationUniform, waterMaxRotationUniform, dryMinRotationUniform, dryMaxRotationUniform;
    private int dryUniformSteps, waterUniformSteps;
    private bool waterUniform, waterGaussian, dryUniform, dryGaussian;
    private bool waterTraining;
    private GameObject spawnedWall, spawnedWaterTree, spawnedDryTree;
    private Vector3 acceleration;
    private bool placingWall, placingWaterTree, placingDryTree;
    private string loadScenarioFile, saveScenarioFile;
    private List<GameObject> waterTreesQueue, dryTreesQueue;

    private Texture2D waterTexture, dryTexture;
    private string waterTextureFile, dryTextureFile;
    private bool waterFixed, dryFixed;
    public Image waterImage, dryImage;

    private string waterTextureFile_LS, dryTextureFile_LS;
    private float deg_LS;

    public bool scenarioLoaded;

    public bool sceneEditing;

    private bool spawnWaterTexture, spawnWaterPattern, spawnDryTexture, spawnDryPattern;
    private float spawnWaterDegree, spawnDryDegree;

    private Texture2D spawnWaterTextureTexture, spawnDryTextureTexture;
    private string spawnWaterTextureFile, spawnDryTextureFile;
    private Image spawnWaterImage, spawnDryImage;

    public bool spawnWaterAngular, spawnWaterAngularBot, spawnWaterAngularTop, spawnDryAngular, spawnDryAngularBot, spawnDryAngularTop;
    public bool waterAngular, dryAngular;
    private float spawnWaterAngularAngle, spawnDryAngularAngle;

    public bool waterAngularTop, waterAngularBot, dryAngularTop, dryAngularBot;
    private float waterAngularAngle, dryAngularAngle;

    private float angle_LS;
    private bool waterTop_LS, waterBot_LS, dryTop_LS, dryBot_LS, waterDouble_LS, waterSpherical_LS, dryDouble_LS, drySpherical_LS;

    private int start, end, inc;
    private bool placed;
    private List<GameObject> treeList;

    public Text activationTimeText, totalTimeText;
    System.DateTime startTime, endTime, generationTime;

    private bool ended, printed, firstRun;

    private Vector2 gridCenter;
    private int gridWidth, gridHeight;

    public GameObject wallButton, waterTreeButton, dryTreeButton;
    private Color buttonColor;

    public Text statusText;

    private bool waterDoubleAngular, dryDoubleAngular, waterSpherical, drySpherical, waterTextured, dryTextured, waterGradient, dryGradient;
    private float waterFixedFloat, dryFixedFloat;
    public GameObject waterAngularTreePrefab, dryAngularTreePrefab;

	private int restrictToCamera;
	private bool restrict;

    private float vFreq;
    private float hFreq;
    private bool changeFreq;

    private float rewardSize;
    private bool rewardSet;
    private bool respawn;

    void Start()
    {
        start = 0;
        inc = 1000;
        end = inc;

        treeList = new List<GameObject>();
    }

    void Update()
    {
        if (!this.placed && this.treeParent.transform.childCount > 0)
        {
            foreach (Transform tr in this.treeParent.transform)
            {
                treeList.Add(tr.gameObject);
            }
            this.placed = true;
        }

        if (start < treeList.Count)
        {
            if (end > treeList.Count)
            {
                end = treeList.Count;
            }

            float locx = treeList[0].transform.position.x;
            float hfreq = treeList[0].GetComponent<WaterTreeScript>().GetShaderHFreq();
            float vfreq = treeList[0].GetComponent<WaterTreeScript>().GetShaderVFreq();
            float r = Random.value;
            // NB edit
            // If there are only 2 or 3 trees, alternate which is visible, and leave the third as constant
            if (Globals.gameType.Equals("detection"))
            {
				if (end == 1 && Globals.varyOrientation) {  // 1-choice detection - vary the orientation of the first trial
					if (r > 0.5) {
						treeList[0].GetComponent<WaterTreeScript>().SetShader(vfreq, hfreq);
						hfreq = treeList[0].GetComponent<WaterTreeScript>().GetShaderHFreq();
						vfreq = treeList[0].GetComponent<WaterTreeScript>().GetShaderVFreq();
					}
					Debug.Log ("[0, 0.5, 1] - " + r);
				}
                if (end == 2)  // 2-choice detection
                {
                    if (r < 0.5)
                    {
                        treeList[1].GetComponent<WaterTreeScript>().Hide();
                        locx = treeList[0].transform.position.x;
                        hfreq = treeList[0].GetComponent<WaterTreeScript>().GetShaderHFreq();
                        vfreq = treeList[0].GetComponent<WaterTreeScript>().GetShaderVFreq();
                    }
                    else
                    {
                        treeList[0].GetComponent<WaterTreeScript>().Hide();
                        locx = treeList[1].transform.position.x;
                        hfreq = treeList[1].GetComponent<WaterTreeScript>().GetShaderHFreq();
                        vfreq = treeList[1].GetComponent<WaterTreeScript>().GetShaderVFreq();
                    }
                    Debug.Log("[0, 0.5, 1] - " + r);
                }
            }
            else if (Globals.gameType.Equals("det_blind"))
            {
                if (r < 0.333)
                {
                    treeList[1].GetComponent<WaterTreeScript>().Hide();
                    locx = treeList[0].transform.position.x;
                    hfreq = treeList[0].GetComponent<WaterTreeScript>().GetShaderHFreq();
                    vfreq = treeList[0].GetComponent<WaterTreeScript>().GetShaderVFreq();
                    //Debug.Log("activated first tree in loader");
                }
                else if (r < 0.667)
                {
                    treeList[0].GetComponent<WaterTreeScript>().Hide();
                    locx = treeList[1].transform.position.x;
                    hfreq = treeList[1].GetComponent<WaterTreeScript>().GetShaderHFreq();
                    vfreq = treeList[1].GetComponent<WaterTreeScript>().GetShaderVFreq();
                    //Debug.Log("activated second tree in loader");
                }
                else
                {
                    treeList[0].GetComponent<WaterTreeScript>().Hide();
                    treeList[1].GetComponent<WaterTreeScript>().Hide();
                    locx = treeList[2].transform.position.x;
                    hfreq = treeList[2].GetComponent<WaterTreeScript>().GetShaderHFreq();
                    vfreq = treeList[2].GetComponent<WaterTreeScript>().GetShaderVFreq();
                    //Debug.Log("deactivated both trees in loader");
                }
                Debug.Log("[0, 0.333, 0.667, 1] - " + r);
            }
            else if (Globals.gameType.Equals("det_target"))
            {
				int treeToActivate = r < 0.5 ? 0 : 1;
				int treeToInactivate = r < 0.5 ? 1 : 0;

				treeList [treeToInactivate].GetComponent<WaterTreeScript> ().Hide ();
				locx = treeList[treeToActivate].transform.position.x;
				hfreq = treeList[treeToActivate].GetComponent<WaterTreeScript>().GetShaderHFreq();
				vfreq = treeList[treeToActivate].GetComponent<WaterTreeScript>().GetShaderVFreq();

				if (Globals.varyOrientation) {
					float r2 = Random.value;
					if (r2 > 0.5) {
						treeList [treeToActivate].GetComponent<WaterTreeScript> ().SetShader (vfreq, hfreq);
						treeList[2].GetComponent<WaterTreeScript> ().SetShader (vfreq, hfreq);
						hfreq = treeList[treeToActivate].GetComponent<WaterTreeScript>().GetShaderHFreq();
						vfreq = treeList[treeToActivate].GetComponent<WaterTreeScript>().GetShaderVFreq();
					}
					Debug.Log("Ori: [0, 0.5, 1] - " + r2);
				}
				Debug.Log("Loc: [0, 0.5, 1] - " + r);
            }
			else if (Globals.gameType.Equals("disc_target"))
			{
				float r2 = Random.value;  // used to set orientation of target or distractor
				int treeToTarget = r < 0.5 ? 0 : 1;
				int treeToDistract = r < 0.5 ? 1 : 0;

				locx = treeList[treeToTarget].transform.position.x;
				hfreq = treeList[treeToTarget].GetComponent<WaterTreeScript>().GetShaderHFreq();
				vfreq = treeList[treeToTarget].GetComponent<WaterTreeScript>().GetShaderVFreq();

				treeList[treeToTarget].GetComponent<WaterTreeScript>().SetCorrect(true);
				treeList[treeToDistract].GetComponent<WaterTreeScript>().SetCorrect(false);

				if (Globals.varyOrientation) {
					if (r2 > 0.5) {
						treeList [treeToTarget].GetComponent<WaterTreeScript> ().SetShader (vfreq, hfreq);
						hfreq = treeList [treeToTarget].GetComponent<WaterTreeScript> ().GetShaderHFreq ();
						vfreq = treeList [treeToTarget].GetComponent<WaterTreeScript> ().GetShaderVFreq ();
					}
					treeList [2].GetComponent<WaterTreeScript> ().SetShader (hfreq, vfreq);

					treeList [treeToDistract].GetComponent<WaterTreeScript> ().SetColors (Globals.distColor1, Globals.distColor2);
					treeList [treeToDistract].GetComponent<WaterTreeScript> ().SetShader (vfreq, hfreq);
				} else {
					if (r2 < 0.5) {
						treeList [treeToDistract].GetComponent<WaterTreeScript> ().SetShader (4, 1);
					} else {
						treeList [treeToDistract].GetComponent<WaterTreeScript> ().SetShader (1, 4);
					}
				}

				Debug.Log("Loc: [0, 0.5, 1] - " + r);
				Debug.Log("Ori: [0, 0.5, 1] - " + r2);
			}
            else if (Globals.gameType.Equals("discrimination"))
            {
                // Randomize orientations on first load
                float targetHFreq0 = treeList[0].GetComponent<WaterTreeScript>().GetShaderHFreq();
                float targetVFreq0 = treeList[0].GetComponent<WaterTreeScript>().GetShaderVFreq();
                float targetHFreq1 = treeList[1].GetComponent<WaterTreeScript>().GetShaderHFreq();
                float targetVFreq1 = treeList[1].GetComponent<WaterTreeScript>().GetShaderVFreq();
                if (r < 0.5)  // Swap orientations between trees
                {
                    treeList[0].GetComponent<WaterTreeScript>().SetShader(targetHFreq1, targetVFreq1);
                    treeList[1].GetComponent<WaterTreeScript>().SetShader(targetHFreq0, targetVFreq0);
                }
                if (Globals.rewardedHFreq == treeList[0].GetComponent<WaterTreeScript>().GetShaderHFreq() &&
                    Globals.rewardedVFreq == treeList[0].GetComponent<WaterTreeScript>().GetShaderVFreq())
                {
                    treeList[0].GetComponent<WaterTreeScript>().SetCorrect(true);
                    treeList[1].GetComponent<WaterTreeScript>().SetCorrect(false);
                    locx = treeList[0].transform.position.x;
                    hfreq = treeList[0].GetComponent<WaterTreeScript>().GetShaderHFreq();
                    vfreq = treeList[0].GetComponent<WaterTreeScript>().GetShaderVFreq();
                }
                else
                {
                    treeList[0].GetComponent<WaterTreeScript>().SetCorrect(false);
                    treeList[1].GetComponent<WaterTreeScript>().SetCorrect(true);
                    locx = treeList[1].transform.position.x;
                    hfreq = treeList[1].GetComponent<WaterTreeScript>().GetShaderHFreq();
                    vfreq = treeList[1].GetComponent<WaterTreeScript>().GetShaderVFreq();
                }
            }
            else if (Globals.gameType.Equals("match") || Globals.gameType.Equals("nonmatch"))  // There are three trees - a central initial tree, and 1 on left and 1 on right
            {
                // First, pick an orientation at random for the central tree
                float targetHFreq = treeList[2].GetComponent<WaterTreeScript>().GetShaderHFreq();
                float targetVFreq = treeList[2].GetComponent<WaterTreeScript>().GetShaderVFreq();

                if (r < 0.5)  // Switch target to opposite of initiation
                {
                    treeList[2].GetComponent<WaterTreeScript>().SetShader(targetVFreq, targetHFreq);
                }
                // Second, randomly pick which side the matching orientation is on
                float rSide = Random.value;
                targetHFreq = treeList[2].GetComponent<WaterTreeScript>().GetShaderHFreq();
                targetVFreq = treeList[2].GetComponent<WaterTreeScript>().GetShaderVFreq();
                if (rSide < 0.5)  // Set the left tree to match
                {
                    treeList[0].GetComponent<WaterTreeScript>().SetShader(targetHFreq, targetVFreq);
                    treeList[1].GetComponent<WaterTreeScript>().SetShader(targetVFreq, targetHFreq);
                    if (Globals.gameType.Equals("match"))
                    {
                        treeList[0].GetComponent<WaterTreeScript>().SetCorrect(true);
                        treeList[1].GetComponent<WaterTreeScript>().SetCorrect(false);
                        locx = treeList[0].transform.position.x;
                        hfreq = treeList[0].GetComponent<WaterTreeScript>().GetShaderHFreq();
                        vfreq = treeList[0].GetComponent<WaterTreeScript>().GetShaderVFreq();
                    }
                    else
                    {
                        treeList[0].GetComponent<WaterTreeScript>().SetCorrect(false);
                        treeList[1].GetComponent<WaterTreeScript>().SetCorrect(true);
                        locx = treeList[1].transform.position.x;
                        hfreq = treeList[1].GetComponent<WaterTreeScript>().GetShaderHFreq();
                        vfreq = treeList[1].GetComponent<WaterTreeScript>().GetShaderVFreq();
                    }
                }
                else // Set the right tree to match
                {
                    treeList[0].GetComponent<WaterTreeScript>().SetShader(targetVFreq, targetHFreq);
                    treeList[1].GetComponent<WaterTreeScript>().SetShader(targetHFreq, targetVFreq);
                    if (Globals.gameType.Equals("match"))
                    {
                        treeList[0].GetComponent<WaterTreeScript>().SetCorrect(false);
                        treeList[1].GetComponent<WaterTreeScript>().SetCorrect(true);
                        locx = treeList[1].transform.position.x;
                        hfreq = treeList[1].GetComponent<WaterTreeScript>().GetShaderHFreq();
                        vfreq = treeList[1].GetComponent<WaterTreeScript>().GetShaderVFreq();
                    }
                    else
                    {
                        treeList[0].GetComponent<WaterTreeScript>().SetCorrect(true);
                        treeList[1].GetComponent<WaterTreeScript>().SetCorrect(false);
                        locx = treeList[0].transform.position.x;
                        hfreq = treeList[0].GetComponent<WaterTreeScript>().GetShaderHFreq();
                        vfreq = treeList[0].GetComponent<WaterTreeScript>().GetShaderVFreq();
                    }
                }
            }
            GameObject.Find("GameControl").GetComponent<GameControlScript>().OccludeTree(locx);  // Will occlude tree if tree visibility is to be restricted to 1 FOV

            Globals.targetLoc.Add(locx);
            Globals.targetHFreq.Add(hfreq);
            Globals.targetVFreq.Add(vfreq);

            for (int i = start; i < end; i++)
            {
                treeList[i].SetActive(true);
            }
            System.GC.Collect();

            start += inc;
            end += inc;
        }
        else if (start > 0 && start >= treeList.Count)
        {
            this.scenarioLoaded = true;          
        }
    }

	public void LoadScenario()
	{
		// Clear trees that appear onscreen before level is loaded
		GameObject[] gos;
		gos = GameObject.FindGameObjectsWithTag("water");
		foreach (GameObject go2 in gos) {
			Object.Destroy (go2);
		}

        if (File.Exists(PlayerPrefs.GetString("scenarioFolder") + "/" + this.loadScenarioFile))// && this.movementRecorderScript.GetReplayFileName() != "")
        {

            XmlDocument xmlDoc = new XmlDocument(); // xmlDoc is the new xml document.
            xmlDoc.LoadXml(File.ReadAllText(PlayerPrefs.GetString("scenarioFolder") + "/" + this.loadScenarioFile, ASCIIEncoding.ASCII)); // load the file.

            XmlNodeList waterConfigList = xmlDoc.SelectNodes("document/config/waterConfig");
            foreach (XmlNode xn in waterConfigList)
            {
                string waterTrainingXML = xn["training"].InnerText;

                if (waterTrainingXML == "True")
                {
                    this.waterTraining = true;
                }
                else
                {
                    this.waterTraining = false;
                }

                string waterDistType = xn["distType"].InnerText;
                if (waterDistType == "f" && xn["waterTex"] != null)
                {
                    this.waterTextureFile_LS = xn["waterTex"].InnerText;
                }

                if (xn["waterAngular"] != null)
                {
                    string angularPos = xn["waterAngular"].InnerText;

                    if (angularPos == "top")
                    {
                        this.waterTop_LS = true;
                        this.waterBot_LS = false;
                        this.waterDouble_LS = false;
                        this.waterSpherical_LS = false;
                    }
                    else if (angularPos == "bot")
                    {
                        this.waterBot_LS = true;
                        this.waterTop_LS = false;
                        this.waterDouble_LS = false;
                        this.waterSpherical_LS = false;
                    }
                    else if (angularPos == "double")
                    {
                        this.waterDouble_LS = true;
                        this.waterTop_LS = false;
                        this.waterBot_LS = false;
                        this.waterSpherical_LS = false;
                    }
                    else if (angularPos == "spherical")
                    {
                        this.waterSpherical_LS = true;
                        this.waterDouble_LS = false;
                        this.waterTop_LS = false;
                        this.waterBot_LS = false;
                        
                    }
                }
            }

            XmlNodeList dryConfigList = xmlDoc.SelectNodes("document/config/dryConfig");
            foreach (XmlNode xn in dryConfigList)
            {
                string dryDistType = xn["distType"].InnerText;
                if (dryDistType == "f" && xn["dryTex"] != null)
                {
                    this.dryTextureFile_LS = xn["dryTex"].InnerText;
                }

                if (xn["dryAngular"] != null)
                {
                    string angularPos = xn["dryAngular"].InnerText;
                    {
                        if (angularPos == "top")
                        {
                            this.dryTop_LS = true;
                            this.dryBot_LS = false;
                            this.dryDouble_LS = false;
                            this.drySpherical_LS = false;
                        }
                        else if (angularPos == "bot")
                        {
                            this.dryBot_LS = true;
                            this.dryTop_LS = false;
                            this.dryDouble_LS = false;
                            this.drySpherical_LS = false;
                        }
                        else if (angularPos == "double")
                        {
                            this.dryDouble_LS = true;
                            this.dryBot_LS = false;
                            this.dryTop_LS = false;
                            this.drySpherical_LS = false;
                        }
                        else if (angularPos == "spherical")
                        {
                            this.drySpherical_LS = true;
                            this.dryTop_LS = false;
                            this.dryBot_LS = false;
                            this.dryDouble_LS = false;
                        }
                    }
                }  
            }

            Globals.gameType = "detection";
            Globals.gameTurnControl = "yaw";
            Globals.varyOrientation = false;
            XmlNodeList gameConfigList = xmlDoc.SelectNodes("document/config/gameConfig");
            foreach (XmlNode xn in gameConfigList)
            {
                if (xn["gameType"] != null)
                {
                    Globals.gameType = xn["gameType"].InnerText;
                }

                if (xn["gameTurnControl"] != null)
                {
                    string gameTurnControlXML = xn["gameTurnControl"].InnerText;
                    if (gameTurnControlXML.Equals("roll"))
                        Globals.gameTurnControl = gameTurnControlXML;
                }

                if (xn["varyOrientation"] != null)
                {
                    string varyOrientationXML = xn["varyOrientation"].InnerText;
                    if (varyOrientationXML.Equals("true"))
                        Globals.varyOrientation = true;
                }
                if (xn["rewardedHFreq"] != null)
                {
                    float.TryParse(xn["rewardedHFreq"].InnerText, out Globals.rewardedHFreq);
                }
                if (xn["rewardedVFreq"] != null)
                {
                    float.TryParse(xn["rewardedVFreq"].InnerText, out Globals.rewardedVFreq);
                }
				if (xn["distractorIntensity1"] != null)
				{
					float i1;
					float.TryParse(xn["distractorIntensity1"].InnerText, out i1);
					Globals.distColor1 = new Color (i1, i1, i1);
				}
				if (xn["distractorIntensity2"] != null)
				{
					float i2;
					float.TryParse(xn["distractorIntensity2"].InnerText, out i2);
					Globals.distColor2 = new Color (i2, i2, i2);
				}
            }

            XmlNodeList levelsList = xmlDoc.GetElementsByTagName("t"); // array of the level nodes.
            foreach (XmlNode node in levelsList)
            {
                bool water = false;
                Vector3 v = Vector3.zero;
                XmlNodeList levelcontent = node.ChildNodes;

                GameObject go;

                bool angular, gradient, texture;
                gradient = false;
                angular = false;
                texture = false;
				restrict = false;
                changeFreq = false;
                rewardSet = false;
                respawn = true;

                foreach (XmlNode val in levelcontent)
                {
                    if (val.Name == "w")
                    {
                        water = (val.InnerText == "1") ? true : false;
                    }
                    if (val.Name == "pos")
                    {
                        float x, y, z;
                        float.TryParse(val.InnerText.Split(';')[0], out x);
                        float.TryParse(val.InnerText.Split(';')[1], out y);
                        float.TryParse(val.InnerText.Split(';')[2], out z);

                        v = new Vector3(Mathf.RoundToInt(x), Mathf.RoundToInt(y), Mathf.RoundToInt(z));
                    }
                    if (val.Name == "d")
                    {
                        float.TryParse(val.InnerText, out this.deg_LS);
                        gradient = true;
                    }
                    else if (val.Name == "a")
                    {
                        float.TryParse(val.InnerText, out this.angle_LS);
                        angular = true;
                    }
                    else if (val.Name == "tex")
                    {
                        texture = true;
					}
                    else if (val.Name == "r")
					{
						int.TryParse (val.InnerText, out this.restrictToCamera);
						restrict = true;
					}
                    else if (val.Name == "v")
                    {
                        float.TryParse(val.InnerText, out this.vFreq);
                        if (!changeFreq) this.hFreq = 4;
                        changeFreq = true;
                    }
                    else if (val.Name == "h")
                    {
                        float.TryParse(val.InnerText, out this.hFreq);
                        if (!changeFreq) this.vFreq = 4;
                        changeFreq = true;
                    }
                    else if (val.Name == "rewardSize")
                    {
                        float.TryParse(val.InnerText, out this.rewardSize);
                        rewardSet = true;
                    }
                    else if (val.Name == "respawn")
                    {
                        respawn = (val.InnerText == "1") ? true : false;
                    }
                }
                if (water)
                {
					// Dummy object to reduce repetition in code
					//go = (GameObject)Instantiate(this.waterTreePrefab, v, Quaternion.identity);

					if (gradient) {
						go = (GameObject)Instantiate (this.waterTreePrefab, v, Quaternion.identity);
						go.GetComponent<WaterTreeScript> ().SetShaderRotation (this.deg_LS);
						go.GetComponent<WaterTreeScript> ().SetForTraining (waterTraining);
						go.transform.parent = treeParent.transform;
						go.isStatic = true;
						go.SetActive (false);
						// Implements restriction of a tree to just one side screen
						if (restrict) {
							if (restrictToCamera == 0) {
								go.layer = LayerMask.NameToLayer ("Left Visible Only");
								foreach (Transform t in go.transform) {
									t.gameObject.layer = LayerMask.NameToLayer ("Left Visible Only");
									t.gameObject.AddComponent<SetRenderQueue>();
								}
							} else if (restrictToCamera == 2) {
								go.layer = LayerMask.NameToLayer ("Right Visible Only");
								foreach (Transform t in go.transform) {
									t.gameObject.layer = LayerMask.NameToLayer ("Right Visible Only");
									t.gameObject.AddComponent<SetRenderQueue>();
								}
							}
						}

                        if (changeFreq)
                        {
                            go.GetComponent<WaterTreeScript>().SetShader(this.hFreq, this.vFreq, this.deg_LS);
                        }

                        if (rewardSet)
                        {
                            go.GetComponent<WaterTreeScript>().SetRewardSize(this.rewardSize);
                        }
                        else
                        {
                            go.GetComponent<WaterTreeScript>().SetRewardSize(Globals.rewardSize);
                        }

                        go.GetComponent<WaterTreeScript>().SetRespawn(this.respawn);
					}
                        else if (texture)
                        {
                            go = (GameObject)Instantiate(this.waterTreePrefab, v, Quaternion.identity);
                            go.GetComponent<WaterTreeScript>().ChangeTexture(LoadPNG(this.waterTextureFile_LS));
                            go.GetComponent<WaterTreeScript>().SetForTraining(waterTraining);
                            go.transform.parent = treeParent.transform;
                            go.isStatic = true;
                            go.SetActive(false);
                        }
                        else if (angular)
                        {   
                            if (waterBot_LS)
                            {
                                go = (GameObject)Instantiate(this.waterAngularTreePrefab, v, Quaternion.identity);
                                go.GetComponent<AngularTreeScript>().ShapeShift("single");
                                go.GetComponent<AngularTreeScript>().ChangeBottomRing(angle_LS);
                                go.GetComponent<WaterTreeScript>().SetForTraining(waterTraining);
                                go.transform.parent = treeParent.transform;
                                go.isStatic = true;
                                go.SetActive(false);
                            }
                            else if (waterTop_LS)
                            {
                                go = (GameObject)Instantiate(this.waterAngularTreePrefab, v, Quaternion.identity);
                                go.GetComponent<AngularTreeScript>().ShapeShift("single");
                                go.GetComponent<AngularTreeScript>().ChangeTopRing(angle_LS);
                                go.GetComponent<WaterTreeScript>().SetForTraining(waterTraining);
                                go.transform.parent = treeParent.transform;
                                go.isStatic = true;
                                go.SetActive(false);
                            }
                            else if (waterDouble_LS)
                            {
                                go = (GameObject)Instantiate(this.waterAngularTreePrefab, v, Quaternion.identity);
                                go.GetComponent<AngularTreeScript>().ShapeShift("double");
                                go.GetComponent<AngularTreeScript>().ChangeBottomRing(angle_LS);
                                go.GetComponent<AngularTreeScript>().ChangeTopRing(angle_LS);
                                go.GetComponent<WaterTreeScript>().SetForTraining(waterTraining);
                                go.transform.parent = treeParent.transform;
                                go.isStatic = true;
                                go.SetActive(false);
                            }
                            else if (waterSpherical_LS)
                            {
                                go = (GameObject)Instantiate(this.waterAngularTreePrefab, v, Quaternion.identity);
                                go.GetComponent<AngularTreeScript>().ShapeShift("spherical");
                                go.GetComponent<AngularTreeScript>().ChangeSphereAngle(SphereAngleRemap(angle_LS));
                                go.GetComponent<WaterTreeScript>().SetForTraining(waterTraining);
                                go.transform.parent = treeParent.transform;
                                go.isStatic = true;
                                go.SetActive(false);
                            }
                        }

                }

                else
                {
                    //((GameObject)Instantiate(this.dryTreePrefab, v, Quaternion.identity)).transform.parent = treeParent.transform;
                        if (gradient)
                        {
                            go = (GameObject)Instantiate(this.dryTreePrefab, v, Quaternion.identity);
                            go.GetComponent<DryTreeScript>().SetShaderRotation(this.deg_LS);
                            go.transform.parent = treeParent.transform;
                            go.isStatic = true;
                            go.SetActive(false);
                        }
                        else if (texture)
                        {
                            go = (GameObject)Instantiate(this.dryTreePrefab, v, Quaternion.identity);
                            go.GetComponent<DryTreeScript>().ChangeTexture(LoadPNG(this.dryTextureFile_LS));
                            go.transform.parent = treeParent.transform;
                            go.isStatic = true;
                            go.SetActive(false);
                        }
                        else if (angular)
                        {
                            if (dryBot_LS)
                            {
                                go = (GameObject)Instantiate(this.dryAngularTreePrefab, v, Quaternion.identity);
                                go.GetComponent<AngularTreeScript>().ShapeShift("single");
                                go.GetComponent<AngularTreeScript>().ChangeBottomRing(angle_LS);
                                go.transform.parent = treeParent.transform;
                                go.isStatic = true;
                                go.SetActive(false);
                            }
                            else if (dryTop_LS)
                            {
                                go = (GameObject)Instantiate(this.dryAngularTreePrefab, v, Quaternion.identity);
                                go.GetComponent<AngularTreeScript>().ShapeShift("single");
                                go.GetComponent<AngularTreeScript>().ChangeTopRing(angle_LS);
                                go.transform.parent = treeParent.transform;
                                go.isStatic = true;
                                go.SetActive(false);
                            }
                            else if (dryDouble_LS)
                            {
                                go = (GameObject)Instantiate(this.dryAngularTreePrefab, v, Quaternion.identity);
                                go.GetComponent<AngularTreeScript>().ShapeShift("double");
                                go.GetComponent<AngularTreeScript>().ChangeBottomRing(angle_LS);
                                go.GetComponent<AngularTreeScript>().ChangeTopRing(angle_LS);
                                go.transform.parent = treeParent.transform;
                                go.isStatic = true;
                                go.SetActive(false);
                            }
                            else if (drySpherical_LS)
                            {
                                go = (GameObject)Instantiate(this.dryAngularTreePrefab, v, Quaternion.identity);
                                go.GetComponent<AngularTreeScript>().ShapeShift("spherical");
                                go.GetComponent<AngularTreeScript>().ChangeSphereAngle(SphereAngleRemap(angle_LS));
                                go.transform.parent = treeParent.transform;
                                go.isStatic = true;
                                go.SetActive(false);
                            }
                        }
                }
            }

            XmlNodeList wallConfigList = xmlDoc.GetElementsByTagName("wall");
            foreach (XmlNode xn in wallConfigList)
            {
                Vector3 v = Vector3.zero;
                Vector3 wallRotation = Vector3.zero;
                Vector3 wallScale = Vector3.zero;

                XmlNodeList wallConfigContent = xn.ChildNodes;

                GameObject go;

                foreach (XmlNode val in wallConfigContent)
                {
                    if (val.Name == "pos")
                    {
                        float x, y, z;
                        float.TryParse(val.InnerText.Split(';')[0], out x);
                        float.TryParse(val.InnerText.Split(';')[1], out y);
                        float.TryParse(val.InnerText.Split(';')[2], out z);

                        v = new Vector3(Mathf.RoundToInt(x), Mathf.RoundToInt(y), Mathf.RoundToInt(z));
                    }
                    if (val.Name == "rot")
                    {
                        float x, y, z;
                        
                        float.TryParse(val.InnerText.Split(';')[0], out x);
                        float.TryParse(val.InnerText.Split(';')[1], out y);
                        float.TryParse(val.InnerText.Split(';')[2], out z);

                        wallRotation = new Vector3(x, y, z);
                    }
                    if (val.Name == "scale")
                    {
                        float x, y, z;

                        float.TryParse(val.InnerText.Split(';')[0], out x);
                        float.TryParse(val.InnerText.Split(';')[1], out y);
                        float.TryParse(val.InnerText.Split(';')[2], out z);

                        wallScale = new Vector3(x, y, z);
                    }
                }

                go = (GameObject)Instantiate(this.wallPrefab, v, Quaternion.identity);
                go.transform.eulerAngles = wallRotation;
                go.transform.localScale += wallScale;
                go.isStatic = true;
                go.transform.parent = wallParent.transform;

            }

            this.errorText.text = "";
        }
        else if (!File.Exists(PlayerPrefs.GetString("scenarioFolder") + "/" + this.loadScenarioFile))
        {
            this.errorText.text = "ERROR: File does not exist";
        }
        else if (this.movementRecorderScript.GetReplayFileName() == "")
        {
            this.errorText.text = "ERROR : Replay file does not exist";
        }



        /*        if(this.movementRecorderScript.GetReplayFileName() == "")
                {
                    this.errorText.text = "ERROR: Replay file field empty";
                }*/
    }

    public void SetLoadScenarioName(string s)
    {
        if (!s.EndsWith(".xml"))
            s = s + ".xml";
        Debug.Log(s);
        this.loadScenarioFile = s;
    }
    
    private float map(float s, float a1, float a2, float b1, float b2)
    {
        return Mathf.Clamp(b1 + (s - a1) * (b2 - b1) / (a2 - a1), b1, b2);
    }

    public float SphereAngleRemap(float f)
    {
        float OldMax = 45;
        float OldMin = 0;
        float NewMax = 10;
        float NewMin = 0;
        float OldValue = f;

        float OldRange = (OldMax - OldMin);
        float NewRange = (NewMax - NewMin);
        float NewValue = (((OldValue - OldMin) * NewRange) / OldRange) + NewMin;
        return NewValue;
    }

    public static Texture2D LoadPNG(string filePath)
    {
        Texture2D tex = null;
        byte[] fileData;

        if (File.Exists(filePath))
        {
            fileData = File.ReadAllBytes(filePath);
            tex = new Texture2D(128, 128);
            tex.LoadImage(fileData); //..this will auto-resize the texture dimensions.
        }
        return tex;
    }
}
