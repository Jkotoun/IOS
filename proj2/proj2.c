#include <stdio.h>
#include <sys/types.h>
#include <unistd.h>
#include <sys/wait.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <semaphore.h>
#include <fcntl.h>
#include <time.h>
#include <sys/mman.h>
#include <stdbool.h>

sem_t* noJudge = NULL;
sem_t* confirmed = NULL;
sem_t* allCheckedIn = NULL;
sem_t* checkin = NULL;
sem_t* fileWriteMutex = NULL;
int* action = NULL;
int* inBuilding = NULL;



int* checkedIn = NULL;
int* confirmedInBuilding = NULL;
bool* judgeInside = NULL;
int* confirmedTotal = NULL;
int* confirmedInIteration = NULL;
FILE* file = NULL;

void* sharedMem(size_t size)
{
    return mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_ANONYMOUS| MAP_SHARED , -1, 0);
}
 
void judge(int immigrants_count, int max_enter_delay, int max_confirmation_time)
{
  
    while((*confirmedTotal)<(int)(immigrants_count))
    {
        (*confirmedInIteration) = 0;
        //modulo arithmetic - +1 - interval includes argument
        if(max_enter_delay>0)
        {
            usleep((rand()%(max_enter_delay+1))*1000);
        }
        sem_wait(fileWriteMutex);
        fprintf(file, "%u  : JUDGE  : wants to enter\n",(*action)++);
        sem_post(fileWriteMutex);
        //locks nojudge semaphore
        sem_wait(noJudge);
        sem_wait(fileWriteMutex);
        fprintf(file, "%u  : JUDGE  : enters  : %u  : %u  : %u\n",(*action)++,(*inBuilding) - (*confirmedInBuilding),(*checkedIn) - (*confirmedInBuilding),*inBuilding);
        sem_post(fileWriteMutex);
        sem_wait(checkin);
      
        *judgeInside = true;
        if((*inBuilding) > *(checkedIn))
        {
            sem_wait(fileWriteMutex);
            fprintf(file, "%u  : JUDGE  : waits for imm  : %u  : %u  : %u\n",(*action)++,(*inBuilding) - (*confirmedInBuilding),(*checkedIn) - (*confirmedInBuilding),*inBuilding);
            sem_post(fileWriteMutex);
            //let next immigrant check in
            sem_post(checkin);
            //waits for all to check in
            sem_wait(allCheckedIn);
        }
        //all checked in
        sem_wait(fileWriteMutex);
        fprintf(file, "%u  : JUDGE  : starts confirmation  : %u  : %u  : %u\n",(*action)++,(*inBuilding) - (*confirmedInBuilding),(*checkedIn) - (*confirmedInBuilding),*inBuilding);
        sem_post(fileWriteMutex);
        if(max_confirmation_time>0)
        {
            usleep((rand()%(max_confirmation_time+1)*1000));
        }
        sem_wait(fileWriteMutex);
        //allchecked
        (*confirmedInBuilding) = (*inBuilding);
        (*confirmedTotal)+=(*confirmedInIteration);
         fprintf(file, "%u  : JUDGE  : ends confirmation  : %u  : %u  : %u\n",(*action)++,(*inBuilding) - (*confirmedInBuilding),(*checkedIn) - (*confirmedInBuilding),*inBuilding);
 
        for(unsigned i = 0;i<(unsigned)(*confirmedInIteration);i++)
        {
            sem_post(confirmed);
        }

        sem_post(fileWriteMutex);
        if(max_confirmation_time>0)
        {
            usleep((rand()%(max_confirmation_time+1)*1000));
        }
        sem_wait(fileWriteMutex);
        fprintf(file, "%u  : JUDGE  : leaves  : %u  : %u  : %u\n",(*action)++,(*inBuilding) - (*confirmedInBuilding),(*checkedIn) - (*confirmedInBuilding),*inBuilding);
        sem_post(fileWriteMutex);
        *judgeInside = false;
        //unlock checkin
        sem_post(checkin);
        //unlock noJudge
        sem_post(noJudge);
            
    }
    sem_wait(fileWriteMutex);
    fprintf(file, "%u  : JUDGE  : finishes\n",(*action)++);
     sem_post(fileWriteMutex);
}

void immigrant(int immigrant_id, int max_cert_pickup_time)
{
                
    
    //waits for judge to leave
    sem_wait(noJudge);
    sem_wait(fileWriteMutex);
    (*inBuilding)++;
    (*confirmedInIteration)++;
    fprintf(file, "%u  : IMM %u  : enters  : %u  : %u  : %u\n",(*action)++,immigrant_id,(*inBuilding) - (*confirmedInBuilding),(*checkedIn) - (*confirmedInBuilding),*inBuilding);
    sem_post(fileWriteMutex);
    //next imm can go in
    sem_post(noJudge);
    //close checkin semaphore 
    sem_wait(checkin);
    sem_wait(fileWriteMutex);
    (*checkedIn)++;
    fprintf(file, "%u  : IMM %u  : checks  : %u  : %u  : %u\n",(*action)++,immigrant_id,(*inBuilding) - (*confirmedInBuilding),(*checkedIn) - (*confirmedInBuilding),*inBuilding);
    sem_post(fileWriteMutex);
    if((*judgeInside) == true && (*inBuilding) == (*checkedIn))
    {
        //signal to judge - all checked in
        sem_post(allCheckedIn);  
    }
    else
    {
        //next can go to checkin
        sem_post(checkin);
    }
    //waits for confirmation by judge
    sem_wait(confirmed);
    sem_wait(fileWriteMutex);
    fprintf(file, "%u  : IMM %u  : wants certificate  : %u  : %u  : %u\n",(*action)++,immigrant_id,(*inBuilding) - (*confirmedInBuilding),(*checkedIn) - (*confirmedInBuilding),*inBuilding);
    sem_post(fileWriteMutex);
    //get certificate time
    if(max_cert_pickup_time > 0)
    {
        usleep((rand()%(max_cert_pickup_time+1))*1000);
    }
    sem_wait(fileWriteMutex);
    fprintf(file, "%u  : IMM %u  : got certificate  : %u  : %u  : %u\n",(*action)++,immigrant_id,(*inBuilding) - (*confirmedInBuilding),(*checkedIn) - (*confirmedInBuilding),*inBuilding);
    sem_post(fileWriteMutex);
    sem_wait(noJudge);
    //leaves building 
    sem_wait(fileWriteMutex);
    (*inBuilding)--;
    (*confirmedInBuilding)--;
    (*checkedIn)--;
    fprintf(file, "%u  : IMM %u  : leaves  : %u  : %u  : %u\n",(*action)++,immigrant_id,(*inBuilding) - (*confirmedInBuilding),(*checkedIn) - (*confirmedInBuilding),*inBuilding);
    sem_post(fileWriteMutex);
    //next imm can go out
    sem_post(noJudge);
}
void imm_generator(int immigrants_count, int max_cert_pickup_time, int max_imm_start_delay)
{
    for(int i = 1;i<=immigrants_count;i++)
    {
        if(max_imm_start_delay != 0)
        {
                usleep((rand()%(max_imm_start_delay+1))*1000);
        }
        pid_t imm_proc_id = fork();
        if (imm_proc_id == 0)
        {
            sem_wait(fileWriteMutex);
            fprintf(file, "%u  : IMM %u  : starts\n",(*action)++,i);
            sem_post(fileWriteMutex);
            immigrant(i,max_cert_pickup_time);
            exit(0);
        }
    }
    //wait for all child processes
    while(wait(NULL)>0);
    exit(0);
}
void clean()
{
    //deallocate shared memory
    munmap(action,4);
    munmap(checkedIn,4);
    munmap(confirmedInBuilding,4);
    munmap(inBuilding,4);
    munmap(judgeInside,1);
    munmap(confirmedTotal,4);
    munmap(confirmedInIteration, 4);

    //close semaphores
    sem_close(noJudge);
    sem_unlink("/xkotou06.nojudge");
    sem_close(checkin);
    sem_unlink("/xkotou06.checkin");
    sem_close(allCheckedIn);
    sem_unlink("/xkotou06.allSignedIn");
    sem_close(confirmed);
    sem_unlink("/xkotou06.confirmed");
    sem_close(fileWriteMutex);
    sem_unlink("/xkotou06.fileWrite");


    //close file
    fclose(file);
}
int main(int argc, char *argv[])
{
    //generate random numbers
    srand(time(NULL));
    //args parse
    int immigrants_count = 0;
    int imm_start_delay = 0;
    int judge_enter_delay = 0;
    int certificate_pick_delay = 0;
    int judge_confirm_delay = 0;

    //arguments parsing and error handling
    if(argc != 6)
    {
        fprintf(stderr,"expected 5 arguments\n");
        return 1;
    }

    char *end1, *end2, *end3, *end4;
    //imm count parse
    immigrants_count = strtoul(argv[1],&end1,10);
    if(*end1 != '\0' || immigrants_count<1)
    {
        fprintf(stderr, "invalid immigrants count (only numbers >=1)\n");
        return 1;
    }
    imm_start_delay = strtoul(argv[2],&end1,10);
    judge_enter_delay = strtoul(argv[3],&end2,10);
    certificate_pick_delay = strtoul(argv[4],&end3,10);
    judge_confirm_delay= strtoul(argv[5],&end4,10);
    if(*end1 != '\0' || imm_start_delay>2000 || imm_start_delay<0 || *end2 != '\0' || judge_enter_delay>2000  || judge_enter_delay < 0
    || *end3 != '\0' || certificate_pick_delay>2000 || certificate_pick_delay<0 || *end4 != '\0' || judge_confirm_delay>2000 || judge_confirm_delay<0)
    {
        fprintf(stderr, "invalid delay argument (max 2000, min 0, only numbers)\n");
        return 1;
    }
    file = fopen("proj2.out","w");
    if(file == NULL)
    {
        fprintf(stderr, "Failed to create file\n");
    }
    setbuf(file,NULL);
    //shared memory init
    action = (int*)sharedMem(4);
    checkedIn = (int*)sharedMem(4);
    confirmedInBuilding = (int*)sharedMem(4);
    inBuilding = (int*)sharedMem(4);
    confirmedTotal= (int*)sharedMem(4);
    judgeInside = (bool*)sharedMem(1);
    confirmedInIteration = (int*)sharedMem(4);

    //values init
    *(action) = 1;
    *(checkedIn) = 0;
    *(confirmedInBuilding) = 0;
    *(inBuilding) = 0;
    *(judgeInside) = false;
    *(confirmedTotal) = 0;
    *(confirmedInIteration) = 0;

    
    //semaphores init
    noJudge = sem_open("/xkotou06.nojudge",O_CREAT, 0666, 1);
    checkin = sem_open("/xkotou06.checkin",O_CREAT, 0666, 1);
    allCheckedIn = sem_open("/xkotou06.allSignedIn",O_CREAT, 0666, 0);
    confirmed = sem_open("/xkotou06.confirmed",O_CREAT, 0666, 0);
    fileWriteMutex = sem_open("/xkotou06.fileWrite",O_CREAT, 0666, 1);


    //main processes forks
    pid_t judgeForkPID = fork();
    if(judgeForkPID==0)
    {

        //judge code
        judge(immigrants_count,judge_enter_delay,judge_confirm_delay);
        exit(0);
    }
    pid_t immGeneratorPID = fork();
    if(immGeneratorPID == 0)
    {
        //generator code
        imm_generator(immigrants_count,certificate_pick_delay,imm_start_delay);
        exit(0);
    }

    //wait for both children to end 
    waitpid(immGeneratorPID,NULL,0);
    waitpid(judgeForkPID,NULL,0);
    clean();
    return 0;
}
