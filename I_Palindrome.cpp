#include<bits/stdc++.h>
using namespace std;

int main()
{
    long long n;
    cin >> n;
    long long org = n;
    long long rev = 0; 

    while(n > 0)
    {
        int d = n % 10;
        rev = rev * 10 + d;
        n = n / 10;
    }

    cout << rev << "\n";
    if(rev == org)
        cout << "YES";
    else
        cout << "NO";

    return 0;
}