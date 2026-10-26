#include<bits/stdc++.h>
#include<math.h>
using namespace std;

int main()
{
    int a,b;
    cin>>a>>b;
    float r=(float)a/b;
    cout<<"floor "<<a<<" / "<<b<<" = "<<floor(r)<<"\n";
    cout<<"ceil "<<a<<" / "<<b<<" = "<<ceil(r)<<"\n";
    cout<<"round "<<a<<" / "<<b<<" = "<<round(r)<<"\n";
    return 0;

}