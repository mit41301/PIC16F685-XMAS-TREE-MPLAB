
https://john.toebes.com/projects/electronics#mce_temp_url#

```
function gnomeSort(a[0..size-1]) {
   i := 1
   j := 2
   while i < size {
      if a[i-1] >= a[i] {
         i := j
         j := j + 1
      } else {
         swap a[i-1] and a[i]
         i := i - 1
         if i = 0 {
            i := 1
         }
      }
   }
}
```
