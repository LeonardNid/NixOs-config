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
