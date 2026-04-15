# Git Grundbefehle

## Status & Überblick
```bash
git status          # Was hat sich geändert?
git log --oneline   # Commit-Historie (kompakt)
git diff            # Was wurde geändert (noch nicht gestaged)?
```

## Änderungen committen
```bash
git add datei.txt      # Einzelne Datei stagen
git add .              # Alle Änderungen stagen
git commit -m "Nachricht"  # Commit erstellen
```

## Mit Remote (Forgejo) arbeiten
```bash
git push               # Lokale Commits hochladen
git pull               # Remote-Änderungen holen + mergen
git fetch              # Remote-Änderungen holen (ohne merge)
```

## Branches
```bash
git branch                  # Alle lokalen Branches anzeigen
git checkout -b feature-xy  # Neuen Branch erstellen + wechseln
git checkout main           # Zurück zu main wechseln
git merge feature-xy        # Branch in aktuellen mergen
```

---

# Forgejo Setup

1. SSH-Key erstellen                                                                                              
ssh-keygen -t ed25519 -f ~/.ssh/forgejo      
Erstellt ein Schlüsselpaar — forgejo (privat) und forgejo.pub (öffentlich).                                       

---                                                                                                               
2. Public Key in Forgejo hinterlegen                            
                                                                                                                
Inhalt von ~/.ssh/forgejo.pub in Forgejo unter Settings → SSH Keys → Add Key eingefügt.
                                                                                                                
---
3. SSH-Config anlegen                                                                                             
                                                                                                                
~/.ssh/config mit folgendem Inhalt erstellt, damit SSH automatisch den richtigen Key und Port nutzt:
Host leoserver.tail6bb5cd.ts.net                                                                                  
    IdentityFile ~/.ssh/forgejo                                 
    Port 2222                                                                                                     
                                                                
---
4. Repo auf Forgejo erstellen
                                                                                                                
Entweder über die Web-UI oder per API:
curl -X POST "https://leoserver.tail6bb5cd.ts.net:8095/api/v1/user/repos" \                                       
-H "Authorization: token DEINTOKEN" \                                    
-H "Content-Type: application/json" \                                                                           
-d '{"name": "mein-repo", "private": true}'                   
                                                                                                                
---                                                             
5. Lokales Repo einrichten und pushen                                                                             
git init                                                                                                          
git checkout -b main
git add .                                                                                                         
git commit -m "first commit"                                    
git remote add origin ssh://git@leoserver.tail6bb5cd.ts.net:2222/Draonel/repo.git
git push -u origin main
