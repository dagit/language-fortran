program testdo
   implicit none
   integer i
   integer j

      do 821 kp = 1, nplots
      do 822 ksp = 1, nspp
      biompsp (kp, ksp) = 0.0
  822 continue
  821 continue

   do 15 j=1,5
     do 17 i=1,  42
       print *,i      
     17 continue
   15 continue

end program testdo
