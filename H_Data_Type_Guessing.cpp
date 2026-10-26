#include<bits/stdc++.h>
using namespace std;

int main()
{
    double n,k,a;
    cin>>n>>k>>a;
    if(a!=0)
    {
    double r=n*k/a;
    if(r-(long long)r==0)
    {if(r>=-2147483648&&r<=2147483648)
        cout<<"int"<<"\n";
     else
        cout<<"long long"<<"\n";
    }
    else
        cout<<"double"<<"\n";}
            return 0;
    
}