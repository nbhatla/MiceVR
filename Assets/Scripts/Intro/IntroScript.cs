using UnityEngine;
using System.Collections;



public class IntroScript : MonoBehaviour {

	public UDPSend udpSender;

	public void Awake()
	{
		// This sequence is necessary to initiate the connection, which will reset the arduino
        this.udpSender.ForceStopSolenoid();
        this.udpSender.CheckReward();  // DO NOT DELETE - without this, the BlowerOn command fails

		// Arduino reset needs time to settle before it can respond to commands
		System.Threading.Thread.Sleep(3000);
		this.udpSender.SendBlowerOn();
	}

	public void LoadGenerator()
    {
        Application.LoadLevel("IntroGenerator");
    }

    public void LoadGame()
    {
        Application.LoadLevel("IntroGame");
    }

    public void LoadReplay()
    {
        Application.LoadLevel("IntroReplay");
    }

	public void LoadConfiguration()
	{
		Application.LoadLevel("config");
	}

	public void LoadFreeGame()
	{
		Application.LoadLevel("IntroFreeGame");
	}

	public void Exit()
    {
		this.udpSender.SendBlowerOff();
        Application.Quit();
    }
}
