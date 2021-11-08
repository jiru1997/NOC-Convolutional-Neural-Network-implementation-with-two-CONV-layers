# NOC-Convolutional-Neural-Network-implementation-with-two-CONV-layers
NOC-Convolutional-Neural-Network-implementation with two CONV layers

In this project, we built four CNNs to take the knowledge we learned from classes and papers into practice. Based on the modules we built for homeworks, we implemented the basic network by which we can fetch data from a .txt file, perform convolution calculations, compare the final result with the golden result and report the errors. We also achieved some enhancements like 2D PEs arrays, convolutional layers and data pooling. By doing this project, we learned the basic calculation mechanism of machine learning, and enhanced our skills of using SystemVerilog and teamwork.

In order to make sure the system can work functionally, the control module will send “begin” signals to PEs of the first layer and when they finish their work, the control module will send “begin” signals to the other PEs. The output of the first layer are two 5x5 matrices, and the first matrix will be used as the new feature map for the second layer. Finally, three 5x5 matrices will be sent back to memory. 


You can use QuestaSim to build and run this project.

<img width="701" alt="image" src="https://user-images.githubusercontent.com/66343787/140835323-d0be9386-3071-4ddf-ac35-21657d57b673.png">
