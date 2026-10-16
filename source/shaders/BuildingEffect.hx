package shaders;

class BuildingEffect
{
  public var shader:BuildingShader = new BuildingShader();

  public function new()
  {
    shader.alphaValue.value = [0.0];
  }

  public function addAlpha(alpha:Float)
  {
    shader.alphaValue.value[0] += alpha;
  }

  public function setAlpha(alpha:Float)
  {
    shader.alphaValue.value[0] = alpha;
  }
}
