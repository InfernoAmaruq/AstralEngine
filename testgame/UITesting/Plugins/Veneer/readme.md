# Maintenance
In code relating to the matrix of the UIRoot you may often see the fourth field of the matrix (Mat[4]) being set to 1 or another value
Why? The engine uses Mat[4] = 1 to invalidate matrices, which causes an error to be thrown at the rendering step
UILayout elements may use Mat[4] = z to store Z rotation, since quats are less reliable in that specific case
