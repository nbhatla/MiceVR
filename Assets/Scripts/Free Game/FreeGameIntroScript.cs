﻿using UnityEngine;
using System.Collections;

public class FreeGameIntroScript : MonoBehaviour {

	// Use this for initialization
	void Start () {
        ReadConfig();
	}
	
	// Update is called once per frame
	void Update () {
        if (Input.GetKeyUp(KeyCode.Space))
            Application.LoadLevel("mouseFreeVR");
	}

    private void ReadConfig()
    {

    }
}
