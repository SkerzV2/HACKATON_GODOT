using Godot;
using System;
using System.IO.Ports;
using System.Threading; // Ajout nécessaire pour Thread.Sleep si utilisé pour la reconnexion

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
	
	// Vibration distance control
	float vibrateMaxDistance = 10.0f; // Maximum distance to enable vibration (doubled from 5.0)
	float vibrateHalfDistance = 5.0f; // Distance at which to halve vibration frequency (doubled from 2.5)
	float vibrationBaseInterval = 0.1f; // Base interval for vibration (100ms)
	float currentVibrationInterval = 0.1f; // Current interval, adjusted by distance
	public float nearestCollectibleDistance = float.MaxValue; // Set by JoueurDemo.gd
	bool vibrationStopped = false; // Track if we've already sent the stop command

	//Toutes les variables suivantes sont à définir par vous en fonction des
	//capteurs que vous voulez utiliser

	public int potentiometreUn;
	public int potentiometreDeux;
	public int potentiometreTrois;

	public int boutonUn;
	public int boutonDeux;
	public int boutonTrois;

	public int piezzoUn;
	public int piezzoDeux;
	public int piezzoTrois;

	public int ultrasonUn;
	public int ultrasonDeux;
	public int ultrasonTrois;

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
				SendCharacter('0');
				Thread.Sleep(100); // Small delay between commands
				SendCharacter('0');
				GD.Print("Initial vibration OFF command sent");
			}
			catch (Exception)
			{
				// Ignore errors on startup
			}
		}
	}

	// *** MÉTHODE _Process MODIFIÉE ***
	public override void _Process(double delta)
	{
		// Vérifier d'abord si le port est censé être ouvert
		if (serialPort != null && serialPort.IsOpen)
		{
			try
			{
				// Essayer de lire depuis le port série
				messageSerie = serialPort.ReadLine();
				connected = true; // Si la lecture réussit, nous sommes connectés

				// Traiter le message reçu
				string[] tableauValeurs = messageSerie.Split(':');
				int tailleTableauValeurs = tableauValeurs.Length;

				 //Vérification de sécurité pour éviter IndexOutOfRangeException
				if (tailleTableauValeurs >= 2) // Assurez-vous qu'il y a au moins 2 valeurs
				{
					// On peut utiliser TryParse pour plus de robustesse contre les erreurs de format
					Int32.TryParse(tableauValeurs[0], out ultrasonUn);
					Int32.TryParse(tableauValeurs[1], out potentiometreUn);
					// Ajoutez ici le parsing pour les autres valeurs si nécessaire, avec des vérifications de taille
				}
				else
				{
					// Optionnel: Gérer le cas où les données reçues sont incomplètes
					GD.PrintErr("Données série incomplètes reçues.");
				}
				
				 //Check if we're too far from any collectible
				if (nearestCollectibleDistance > vibrateMaxDistance)
				{
					// Only send the stop command once to avoid flooding
					if (!vibrationStopped)
					{
						// Make sure vibration is turned OFF when too far
						SendCharacter('0');
						GD.Print("Too far from collectible, turning vibration OFF");
						vibrationStopped = true;
						alternate = false; // Reset alternate flag
						vibrationTimer = 0; // Reset timer
					}
				}
				else
				{
					// We're in range for vibration
					vibrationStopped = false;
					
					// Update current vibration interval based on distance
					UpdateVibrationInterval();
					
					// Update vibration timer
					vibrationTimer += (float)delta;
					
					// Send vibration commands based on distance and timer
					if (vibrationTimer >= currentVibrationInterval)
					{
						vibrationTimer = 0;
						if (alternate)
						{
							SendCharacter('1');
							GD.Print($"Sending vibration ON (Distance: {nearestCollectibleDistance:F2}, Interval: {currentVibrationInterval:F2})");
						}
						else
						{
							SendCharacter('0');
							GD.Print($"Sending vibration OFF (Distance: {nearestCollectibleDistance:F2})");
						}
						alternate = !alternate;
					}
				}
			}
			// Gérer les exceptions qui peuvent survenir si l'Arduino est déconnecté
			//catch (TimeoutException)
			//{
				//// Le ReadTimeout a été atteint. Ce n'est pas forcément une erreur critique,
				//// just aucune donnée n'est arrivée à temps.
				//// Vous pouvez ignorer ou logger si besoin.
				 ////GD.Print("Timeout en lecture série.");
				//// Ne pas changer 'connected' ici forcément, la connexion peut toujours être active
			//}
			catch (Exception e) // Attrape les autres erreurs (IOExceptions, etc.)
			{
				// Une erreur s'est produite (déconnexion probable)
				GD.PrintErr($"Erreur de lecture série : {e.Message}");
				connected = false; // Marquer comme déconnecté
				// Optionnel: Fermer le port proprement pour éviter d'autres erreurs
				try
				{
					serialPort.Close();
				}
				catch (Exception closeEx)
				{
					GD.PrintErr($"Erreur lors de la fermeture du port après une erreur de lecture : {closeEx.Message}");
				}
				// serialPort = null; // Mettre à null si vous voulez tenter une réinitialisation complète plus tard
			}
		}
		else
		{
			// Le port n'est pas ouvert (soit il n'a jamais été ouvert, soit il a été fermé suite à une erreur)
			if (connected) // Si on était connecté avant, afficher un message
			{
				GD.Print("Port série non disponible ou fermé.");
				connected = false;
			}
			// Optionnel : Ajouter ici une logique pour tenter de se reconnecter périodiquement
			// exemple très simple :
			// Thread.Sleep(1000); // Attention, Sleep bloque le thread ! À utiliser avec précaution ou via un Timer Godot.
			// simpleInit();
		}
	}
	// *** FIN DE LA MÉTHODE MODIFIÉE ***

	private void UpdateVibrationInterval()
	{
		// If too far, no vibration (interval not relevant)
		if (nearestCollectibleDistance > vibrateMaxDistance)
		{
			currentVibrationInterval = vibrationBaseInterval;
			return;
		}
		
		// If very close, use base interval (fastest vibration)
		if (nearestCollectibleDistance <= vibrateHalfDistance)
		{
			currentVibrationInterval = vibrationBaseInterval;
		}
		// Between half distance and max distance, adjust interval linearly
		else
		{
			float distanceFactor = (nearestCollectibleDistance - vibrateHalfDistance) / (vibrateMaxDistance - vibrateHalfDistance);
			// Scale from 1x to 2x the base interval (slower as distance increases)
			currentVibrationInterval = vibrationBaseInterval * (1.0f + distanceFactor);
		}
	}

	void simpleInit()
	{
		try
		{
			// Si serialPort existe et est ouvert, on le ferme d'abord
			if (serialPort != null && serialPort.IsOpen)
			{
				serialPort.Close();
			}

			serialPort = new SerialPort("COM3", 9600) // ⚠️ Vérifier le bon port COM ici
			{
				ReadTimeout = 500,  // Temps d'attente avant qu'une lecture échoue (ms)
				WriteTimeout = 500, // Temps d'attente avant qu'une écriture échoue (ms) - Ajouté pour la robustesse
				Handshake = Handshake.None, // Désactiver le contrôle de flux
				DtrEnable = true,   // Active Data Terminal Ready pour éviter le reset automatique de l'Arduino
				RtsEnable = true    // Active Request to Send
			};
			serialPort.Open();
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
