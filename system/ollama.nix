{ ... }:

{
    services.ollama = {
        enable = true;

        # Optional: Beschleunigung für deine Grafikkarte aktivieren
        # Nutze "cuda" für Nvidia GPUs oder "rocm" für AMD GPUs
        # acceleration = "cuda"; 
    };

}
