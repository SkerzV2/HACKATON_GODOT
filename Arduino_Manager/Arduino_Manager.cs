using Godot;
using System;
using System.IO.Ports;
using System.Threading; // Ajout nécessaire pour Thread.Sleep si utilisé pour la reconnexion

[GlobalClass]
public partial class Arduino_Manager : Node2D
{
	SerialPort serialPort;

	bool firstTime = true;
	bool alternate = false; // Flag to alternate between sending '1' and '0'

	// TO DELETE	
	float globalTimer;
	float startTime = 0;
	float currentTime;
	string messageSerie;


	bool connected = false; // Utiliser ce booléen pour suivre l'état
	float vibrationTimer = 0; // Timer for vibration alternation
	
	
	public int joystick1x;
	public int joystick1y;
	public int joystick2x;
	public int joystick2y;
	public int bouton1;
	public int bouton2;
	public int bouton3;
	public int boutonJoystick1;
	public int boutonJoystick2;
	public int levier;

	// Called when the node enters the scene tree for the first time.
	public override void _Ready()
	{
		simpleInit(); // Initialisation simple qui prend en compte le port COM définit à la main
		
		// Make sure vibration is OFF when game starts
		if (serialPort != null && serialPort.IsOpen)
		{
			// Send the OFF command twice to ensure it's received
			try
			{
				//SendCharacter('0');
				//Thread.Sleep(100); // Small delay between commands
				//SendCharacter('0');
				GD.Print("Initial vibration OFF command sent");
			}
			catch (Exception)
			{
				GD.Print("Error");
				// Ignore errors on startup
			}
		}
	}

	// *** MÉTHODE _Process MODIFIÉE ***
	// Buffer pour stocker les données lues
	string readBuffer = "";

	public override void _Process(double delta)
	{
		if (serialPort != null && serialPort.IsOpen)
		{
			try
			{
				string incoming = serialPort.ReadExisting();

				if (!string.IsNullOrEmpty(incoming))
				{
					readBuffer += incoming;

					while (true)
					{
						int start = readBuffer.IndexOf('[');
						int end = readBuffer.IndexOf(']');

						if (start != -1 && end > start)
						{
							// Extraire un message complet
							string messageComplet = readBuffer.Substring(start + 1, end - start - 1);
							readBuffer = readBuffer.Substring(end + 1);

							// Debug brut
							//GD.Print(">> Données brutes reçues : [", messageComplet, "]");

							string[] tableauValeurs = messageComplet.Split(':');

							if (tableauValeurs.Length >= 10)
							{
								Int32.TryParse(tableauValeurs[0], out joystick1x);
								Int32.TryParse(tableauValeurs[1], out joystick1y);
								Int32.TryParse(tableauValeurs[2], out joystick2x);
								Int32.TryParse(tableauValeurs[3], out joystick2y);
								Int32.TryParse(tableauValeurs[4], out bouton1);
								Int32.TryParse(tableauValeurs[5], out bouton2);
								Int32.TryParse(tableauValeurs[6], out bouton3);
								Int32.TryParse(tableauValeurs[7], out boutonJoystick1);
								Int32.TryParse(tableauValeurs[8], out boutonJoystick2);
								Int32.TryParse(tableauValeurs[9], out levier);

								//GD.Print("JOYSTICKS : ", joystick1x, ", ", joystick1y, " | ", joystick2x, ", ", joystick2y);
								//GD.Print("BOUTONS : ", bouton1, bouton2, bouton3, " | BTN_JS1: ", boutonJoystick1, " BTN_JS2: ", boutonJoystick2);
								//GD.Print("LEVIER : ", levier);

								connected = true;
							}
							else
							{
								GD.PrintErr("Message incomplet ou mal formaté : ", messageComplet);
							}
						}
						else
						{
							break; // Pas encore de message complet
						}
					}
				}
			}
			catch (Exception e)
			{
				GD.PrintErr($"Erreur de lecture série : {e.Message}");
				connected = false;

				try { serialPort.Close(); } catch (Exception closeEx) {
					GD.PrintErr($"Erreur lors de la fermeture du port : {closeEx.Message}");
				}
			}
		}
		else
		{
			if (connected)
			{
				GD.Print("Port série non disponible ou fermé.");
				connected = false;
			}

			// Tu peux ajouter une tentative de reconnexion ici si tu veux
		}
	}


	// *** FIN DE LA MÉTHODE MODIFIÉE ***


	void simpleInit()
	{
		try
		{
			// Si serialPort existe et est ouvert, on le ferme d'abord
			if (serialPort != null && serialPort.IsOpen)
			{
				serialPort.Close();
			}

			serialPort = new SerialPort("COM5", 9600) // ⚠️ Vérifier le bon port COM ici
			{
				ReadTimeout = 500,  // Temps d'attente avant qu'une lecture échoue (ms)
				WriteTimeout = 500, // Temps d'attente avant qu'une écriture échoue (ms) - Ajouté pour la robustesse
				Handshake = Handshake.None, // Désactiver le contrôle de flux
				DtrEnable = true,   // Active Data Terminal Ready pour éviter le reset automatique de l'Arduino
				RtsEnable = true    // Active Request to Send
			};
			serialPort.Open();
			GD.Print(serialPort.IsOpen);
			GD.Print("Port série ouvert avec succès !");
			connected = true; // Marquer comme connecté après ouverture réussie
		}
		catch (Exception e)
		{
			GD.PrintErr($"Erreur d'ouverture du port COM6 : {e.Message}");
			// GD.PrintErr("Vérifiez si l'Arduino est connecté et si le port COM est correct."); // Message plus utile
			serialPort = null; // Important: mettre à null si l'ouverture échoue
			connected = false; // Marquer comme non connecté
		}
	}

	public void SendCharacter(char character)
	{
		// Vérifier si le port série est valide et ouvert avant d'envoyer
		if (serialPort != null && serialPort.IsOpen)
		{
			try
			{
				GD.Print("VIBRATION ASKED !!");
				// Écrire le caractère sur le port série
				serialPort.Write(character.ToString());
				
				// Debug output specifically for vibration commands
				if (character == '1')
				{
					GD.Print("Arduino: Vibration ON");
				}
				else if (character == '0')
				{
					GD.Print("Arduino: Vibration OFF");
				}
			}
			catch (Exception ex)
			{
				GD.PrintErr($"Erreur lors de l'envoi du caractère '{character}' : {ex.Message}");
				// Gérer l'erreur d'écriture (peut aussi indiquer une déconnexion)
				connected = false;
				 try { serialPort.Close(); } catch {}
			}
		}
		else
		{
			 // Ne pas considérer comme une erreur si on sait déjà qu'on est déconnecté
			if(connected) GD.PrintErr("Erreur d'envoi : Port série non disponible !");
		}
	}
	private void _on_button_toggled(bool toggled_on)
	{
		SendCharacter(toggled_on ? '1' : '0');
	}

	// Optionnel: Méthode pour fermer proprement le port en quittant
	public override void _ExitTree()
	{
		if (serialPort != null && serialPort.IsOpen)
		{
			try
			{
				// Make sure vibration is off
				SendCharacter('0');
				
				GD.Print("Fermeture du port série.");
				serialPort.Close();
			}
			catch (Exception e)
			{
				GD.PrintErr($"Erreur lors de la fermeture du port série : {e.Message}");
			}
		}
	}
}
