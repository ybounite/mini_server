#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <netdb.h>
#include <sys/socket.h>
#include <netinet/in.h>
typedef struct s_client
{
    int id;
    char msg[110000];
}   t_client;
char bufRead[120000], bufWrite[120000];

t_client clients[1024];

struct sockaddr_in servaddr;
socklen_t addlen = sizeof(servaddr);
fd_set readfds, writefds, nfds;

int max, next_id = 0;
void send_all(int s)
{
    for(int i = 0; i <= max; i++)
    {
        if (FD_ISSET(i, &writefds) && i != s)
            send(i, bufWrite, strlen(bufWrite), 0);
    }
}
void error(char *str)
{
    write(2, str, strlen(str));
    write(2, "\n", 1);
    exit(1);
}

int createServer(int port)
{
    bzero(clients, sizeof(clients));
    FD_ZERO(&nfds);

    int sockfd = socket(AF_INET, SOCK_STREAM, 0);
	if (sockfd == -1)
		error("socket creation failed...\n");
	else
		printf("Socket successfully created..\n");
	bzero(&servaddr, sizeof(servaddr));
	FD_SET(sockfd, &nfds);
    max = sockfd;

	// assign IP, PORT 
	servaddr.sin_family = AF_INET; 
	servaddr.sin_addr.s_addr = htonl(2130706433); //127.0.0.1
	servaddr.sin_port = htons(port); 

	// Binding newly created socket to given IP and verification 
	if ((bind(sockfd, (const struct sockaddr *)&servaddr, sizeof(servaddr))) != 0)
		error("socket bind failed...\n");
	else
		printf("Socket successfully binded..\n");
	if (listen(sockfd, 128) != 0)
		error("cannot listen\n");
    return sockfd;
}

void    stratServer(int sockfd)
{
    while(1)
    {
        readfds = writefds = nfds;
        if (select(max+1, &readfds, &writefds, NULL, NULL) < 0)  
            continue ;
        for(int s = 0; s <= max; s++)
        {
            if (FD_ISSET(s, &readfds) && s == sockfd)
            {
                int newClient = accept(sockfd, (struct sockaddr *)&servaddr, &addlen);
                if (newClient < 0)
                    continue ;
                clients[newClient].id = next_id++;
                max = (newClient > max) ? newClient : max;
                FD_SET(newClient, &nfds);
                sprintf(bufWrite, "server: client %d just arrived\n", clients[newClient].id);
                send_all(newClient);
                break ;
            }
            else if(FD_ISSET(s, &readfds) && s != sockfd)
            {
                int res = recv(s, bufRead, sizeof(bufRead), 0);
                if (res <= 0)
                {
                    sprintf(bufWrite,  "server: client %d just left\n", clients[s].id);
                    FD_CLR(s, &nfds);
                    send_all(s);
                    close(s);
                    break ;
                }
                int j = strlen(clients[s].msg);
                for(int i = 0; i < res; i++)
                {
                    clients[s].msg[j] = bufRead[i];
                    if (clients[s].msg[j] == '\n')
                    {
                        clients[s].msg[j] = '\0';
                        sprintf(bufWrite,  "client %d: %s\n", clients[s].id, clients[s].msg);
                        bzero(clients[s].msg, sizeof(clients[s].msg));
                        send_all(s);
                        j = 0;
                    }
                    j++;
                }
                break ;
            }
        }
    }
}
int main(int ac, char **av)
{
    if (ac != 2)
        error("Wrong number of arguments");
    int sockfd = createServer(atoi(av[1]));
    stratServer(sockfd);
    return 0;
}