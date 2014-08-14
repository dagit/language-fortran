program testdo
   implicit none
   integer i
   integer j

   do j=1,5
     do 17 i=1,  42
       print *,i      
     17 continue
   end do

end program testdo
